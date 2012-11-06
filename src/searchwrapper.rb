=begin
This file is part of ebayshopping.

Nome-Programma is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Nome-Programma is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Nome-Programma.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'ebservice.rb'
require 'set'

MaxResults = 1000
SearchInfo = Struct.new(:text, :sortMode, :paymentModes, :location, :localSearch)

class SearchWrapper < Ebay::EbService
	#See: http://developer.ebay.com/DevZone/finding/CallRef/findItemsByKeywords.html#Request.sortOrder
	@@SortModes = %w{
		BestMatch BidCountFewest BidCountMost CountryAscending CountryDescending
		CurrentPriceHighest DistanceNearest EndTimeSoonest CurrentPriceLowest
		PricePlusShippingHighest PricePlusShippingLowest StartTimeNewest
	}
	BestMatch = @@SortModes.index("BestMatch")
	SortDistAsc = @@SortModes.index("DistanceNearest")
	SortPriceAsc = @@SortModes.index("CurrentPriceLowest")
	SortExpiringAsc = @@SortModes.index("EndTimeSoonest")
	SortBidsAsc = @@SortModes.index("BidCountFewest")
	SortPriceDesc = @@SortModes.index("CurrentPriceHighest")
	SortExpiringDesc = @@SortModes.index("StartTimeNewest")
	SortBidsDesc = @@SortModes.index("BidCountMost")
	SortCountryAsc = @@SortModes.index("CountryAscending")
	SortCountryDesc = @@SortModes.index("CountryDescending")
	SortPriceShippingAsc = @@SortModes.index("PricePlusShippingLowest")
	SortPriceShippingDesc = @@SortModes.index("PricePlusShippingHighest")

	attr_reader :appID, :maxResults
	attr_accessor :localSearchOnly

	def initialize(parCountry, parAppID, parSandboxMode, parSSL, parMaxResults)
		super(parSandboxMode, parSSL, parCountry)
		@appID = parAppID
		@postalCode = nil
		@localSearchOnly = false
		@maxResults = [parMaxResults.is_a?(Fixnum) && parMaxResults || MaxResults, MaxResults].min
		@maxDistanceForDupFilter = 1
		nil
	end

	def postalCode()
		return @postalCode
	end

	def postalCode=(parNew)
		raise ArgumentError, "Postal code must be a string" unless parNew.is_a?(String) || parNew.nil?
		@postalCode = parNew
	end

	def each_result(parKeywords, parFilterDups)
		isSearchInfo = parKeywords.is_a?(SearchInfo)
		raise ArgumentError, "Invalid parameter type: \"#{parKeywords.class.name}\"" unless parKeywords.is_a?(String) || isSearchInfo
		raise ArgumentError, "Unclean keywords" if parKeywords.tainted?

		searchInfo = (isSearchInfo ? parKeywords : makeDefaultSearchInfo(parKeywords))

		retArray = nil
		pageNum = 1
		z = 0
		metItems = Hash.new
		allowYield = true
		while (retArray = self.getPageResult(searchInfo, pageNum)).size > 0 do
			retArray.each do |itm|
				itm["internalItemNum"] = z
				itm["internalPageNum"] = pageNum
				if parFilterDups then
					sellerInfo = itm["sellerInfo"].first
					sellerUserName = (sellerInfo.has_key?("sellerUserName") ? sellerInfo["sellerUserName"].first : "%\\!__reserved no user name for this seller :/")
					allowYield = !isResultDuplicate(itm["title"], sellerUserName, metItems)
				end

				yield(itm) if allowYield
				z += 1
				raise StopIteration if z == @maxResults
			end
			pageNum += 1
		end
		raise StopIteration
	end

	def getPageResult(parKeywords, parPage)
		isSearchInfo = parKeywords.is_a?(SearchInfo)
		raise ArgumentError, "Invalid parameter type: \"#{parKeywords.class.name}\"" unless parKeywords.is_a?(String) || isSearchInfo
		raise ArgumentError, "Unclean keywords" if parKeywords.tainted?
		return Array.new if parPage > 100 #Apparently the api has a hard limit

		searchInfo = (isSearchInfo ? parKeywords : makeDefaultSearchInfo(parKeywords))

		params = { "keywords" => searchInfo.text }
		params["paginationInput"] = {"pageNumber" => parPage.to_s, "entriesPerPage" => "100"}
		params["sortOrder"] = @@SortModes[searchInfo.sortMode]
		params["buyerPostalCode"] = searchInfo.location unless searchInfo.location.nil?
		params["outputSelector"] = (params.fetch("outputSelector", Array.new) << "SellerInfo")
		if searchInfo.localSearch then
			params["itemFilter"] = (params.fetch("itemFilter", Array.new) << { "name" => "LocalSearchOnly", "value" => "true" })
		end

		hResult = self.callService(:FindingService, "findItemsByKeywords", "1.11.0", params, @appID)

		#ack, version, timestamp, searchResult, paginationOutput, itemSearchURL
		if !hResult["ack"].is_a?(Array) || hResult["ack"].first != "Success" then
			raise StandardError, "Search failed with error: #{hResult["ack"]}"
		end

		retSize = hResult["searchResult"].first["@count"].to_i
		retVal = hResult["searchResult"].first["item"]
		raise StandardError, "Query result reports a count of #{retSize} items, but then returned #{retVal.size} items" if retSize != retVal.size
		retVal
	end

	def makeDefaultSearchInfo(parText)
		raise ArgumentError, "Invalid parameter type: \"#{parText.class.name}\"" unless parText.is_a?(String)
		locSearch = (@localSearchOnly ? true : false)
		retVal = SearchInfo.new(parText, SortDistAsc, nil, @postalCode, locSearch)
		retVal
	end

	def levenshteinDistance(s, t)
		len_s = s.length
		len_t = t.length
		cost = 0

		if s[0] != t[0] then
			cost = 1
		end

		if len_s == 0 then
			return len_t
		elsif len_t == 0 then
			return len_s
		else
			return [levenshteinDistance(s[1..len_s-1], t) + 1, levenshteinDistance(s, t[1..len_t-1]) + 1, levenshteinDistance(s[1..len_s-1], t[1..len_t-1]) + cost].min
		end
	end

	def isResultDuplicate(parTitle, parSeller, parCacheTable)
		isDuplicate = false
		currSet = parCacheTable.fetch(parSeller, Set.new)
		currSet.each do |strTitle|
			if levenshteinDistance(parTitle, strTitle) <= @maxDistanceForDupFilter then
				isDuplicate = true
				break
			end
		end
		currSet.add(parTitle)
		parCacheTable[parSeller] = currSet
		isDuplicate
	end

	private :makeDefaultSearchInfo, :levenshteinDistance, :isResultDuplicate
end
