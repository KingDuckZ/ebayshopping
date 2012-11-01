require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Ebay
	BaseURL = 'svcs.ebay.com'
	BaseURL_Sandbox = 'svcs.sandbox.ebay.com'
	ServiceVersion = "v1"
	
	ServicePaths = {
		:FindingService => '/services/search/FindingService/' + ServiceVersion + '?OPERATION-NAME=%OPERATION%'
	}
	
	class EbService
		attr_reader :sandboxMode

		def initialize(parSandboxMode, parSSL, parCountry)
			port = (parSSL ? 443 : 80)
			baseUrl = parSandboxMode ? BaseURL_Sandbox : BaseURL
			@httpObj = Net::HTTP.new(baseUrl, port)
			@httpObj.use_ssl = (parSSL ? true : false)
			@country = parCountry || "IT"
			@sandboxMode = (parSandboxMode ? true : false)
			nil
		end
	
		def callService(parName, parOperation, parVersion, parData, parAppID)
			raise ArgumentError, "parName must be a Symbol, received a \"#{parName.class.name}\" instead" unless parName.is_a?(Symbol)
			raise ArgumentError, "parOperation must be a string, received a \"#{parOperation.class.name}\" instead" unless parOperation.is_a?(String)
			raise NameError, "Can't find a corresponding value for key \"#{parName}\"" unless ServicePaths.has_key?(parName)

			envelop = {
				"jsonns.xsi" => "http://www.w3.org/2001/XMLSchema-instance",
				"jsonns.xs" => "http://www.w3.org/2001/XMLSchema",
				"tns.#{parOperation}Request" => parData
			}
			headers = {
				"X-EBAY-SOA-SERVICE-NAME" => parName.to_s,
				"X-EBAY-SOA-OPERATION-NAME" => parOperation,
				"X-EBAY-SOA-SERVICE-VERSION" => parVersion,
				"X-EBAY-SOA-GLOBAL-ID" => "EBAY-#{@country}",
				"X-EBAY-SOA-SECURITY-APPNAME" => parAppID,
				"X-EBAY-SOA-REQUEST-DATA-FORMAT" => "JSON",
			}
	
			findPath = ServicePaths[parName].gsub("%OPERATION%", parOperation)
			res = @httpObj.post(findPath, envelop.to_json, headers)
			JSON.parse(res.body)
		end
	end
end
