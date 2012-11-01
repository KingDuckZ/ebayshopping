require 'net/http.rb'
require 'json'

class ApiWrapper
#	@@BaseURL = 'svcs.ebay.com'
#	@@AppID = "Dev009d5c-57c5-4c49-854b-d6a41365508"
	@@BaseURL = 'svcs.sandbox.ebay.com'
	@@AppID = "Dev00793b-c9f4-4930-9a45-1c9d897f958"
	@@ServiceVersion = "v1"
	@@FindingService = '/services/search/FindingService/' + @@ServiceVersion + '?OPERATION-NAME='

	def initialize(parCountry)
		@httpObj = Net::HTTP.new(@@BaseURL)
		@country = parCountry || "IT"
		nil
	end

	def findByKeywords(parKeywords)
		raise "Invalid parameter type: \"#{parKeywords.class.name}\"" unless parKeywords.is_a?(String)
		raise "Unclean keywords" if parKeywords.tainted?

		findByKeyword = 'findItemsByKeywords'
		findPath = @@FindingService + findByKeyword
		params = {
			"keywords" => parKeywords
		}
		envelop = {
			"jsonns.xsi" => "http://www.w3.org/2001/XMLSchema-instance",
			"jsonns.xs" => "http://www.w3.org/2001/XMLSchema",
			"tns.findItemsByKeywordsRequest" => params
		}
		headers = {
			"X-EBAY-SOA-SERVICE-NAME" => "FindingService",
			"X-EBAY-SOA-OPERATION-NAME" => findByKeyword,
			"X-EBAY-SOA-SERVICE-VERSION" => "1.11.0",
			"X-EBAY-SOA-GLOBAL-ID" => "EBAY-#{@country}",
			"X-EBAY-SOA-SECURITY-APPNAME" => @@AppID,
			"X-EBAY-SOA-REQUEST-DATA-FORMAT" => "JSON",
		}

		res = @httpObj.post(findPath, envelop.to_json, headers)
		res.body
	end
end

obj = ApiWrapper.new("IT")
retVal = obj.findByKeywords("hard disk")
puts retVal
