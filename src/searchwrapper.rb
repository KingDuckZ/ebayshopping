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

class SearchWrapper < Ebay::EbService
	#See: http://developer.ebay.com/DevZone/finding/CallRef/findItemsByKeywords.html#Request.sortOrder
	@@SortModes = %w{
		BestMatch BidCountFewest BidCountMost CountryAscending CountryDescending
		CurrentPriceHighest DistanceNearest EndTimeSoonest
		PricePlusShippingHighest PricePlusShippingLowest StartTimeNewest
	}

	attr_reader :appID
	attr_accessor :localSearchOnly

	def initialize(parCountry, parAppID, parSandboxMode, parSSL)
		super(parSandboxMode, parSSL, parCountry)
		@appID = parAppID
		@postalCode = nil
		@localSearchOnly = false
		@sortMode = 0
		nil
	end

	def sortMode()
		return @@SortModes[@sortMode]
	end

	def postalCode()
		return @postalCode
	end

	def postalCode=(parNew)
		raise ArgumentError, "Postal code must be a string" unless parNew.is_a?(String) || parNew.nil?
		@postalCode = parNew
	end

	def each_result(parKeywords)
		raise ArgumentError, "Invalid parameter type: \"#{parKeywords.class.name}\"" unless parKeywords.is_a?(String)
		raise ArgumentError, "Unclean keywords" if parKeywords.tainted?

		retArray = nil
		pageNum = 1
		z = 0
		while (retArray = self.getPageResult(parKeywords, pageNum)).size > 0 do
			retArray.each do |itm|
				itm["internalItemNum"] = z
				itm["internalPageNum"] = pageNum
				yield(itm)
				z += 1
			end
			pageNum += 1
		end
		raise StopIteration
	end

	def getPageResult(parKeywords, parPage)
		raise ArgumentError, "Invalid parameter type: \"#{parKeywords.class.name}\"" unless parKeywords.is_a?(String)
		raise ArgumentError, "Unclean keywords" if parKeywords.tainted?
		return Array.new if parPage > 100 #Apparently the api has a hard limit

		params = { "keywords" => parKeywords }
		params["paginationInput"] = {"pageNumber" => parPage.to_s, "entriesPerPage" => "100"}
		params["sortOrder"] = @@SortModes[@sortMode]
		params["buyerPostalCode"] = @postalCode unless @postalCode.nil?
		if @localSearchOnly then
			params.fetch("itemFilter", Array.new) << { "name" => "LocalSearchOnly", "value" => "true" }
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
end
