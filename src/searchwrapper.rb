require 'ebservice.rb'

class SearchWrapper < Ebay::EbService
	attr_reader :appID
	attr_accessor :localSearchOnly

	def initialize(parCountry, parAppID, parSandboxMode, parSSL)
		super(parSandboxMode, parSSL, parCountry)
		@appID = parAppID
		@postalCode = nil
		@localSearchOnly = false
		nil
	end

	def postalCode()
		return @postalCode
	end

	def postalCode=(parNew)
		raise ArgumentError, "Postal code must be a string" unless parNew.is_a?(String) || parNew.nil?
		@postalCode = parNew
	end

	def findByKeywords(parKeywords)
		raise ArgumentError, "Invalid parameter type: \"#{parKeywords.class.name}\"" unless parKeywords.is_a?(String)
		raise ArgumentError, "Unclean keywords" if parKeywords.tainted?

		params = { "keywords" => parKeywords }
		unless @postalCode.nil? then
			params["buyerPostalCode"] = @postalCode
			params["sortOrder"] = "Distance"
		end
		if @localSearchOnly then
			params.fetch("itemFilter", Array.new) << { "name" => "LocalSearchOnly", "value" => "true" }
		end

		self.callService(:FindingService, "findItemsByKeywords", "1.11.0", params, @appID)
	end
end
