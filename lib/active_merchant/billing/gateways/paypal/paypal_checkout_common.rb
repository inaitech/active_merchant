module ActiveMerchant
  module Billing
    module PaypalCheckoutCommon

      URLS = {
        :test_url     => "https://api.sandbox.paypal.com",
        :live_url     => "https://api.paypal.com"
      }

      ALLOWED_INTENT              = %w(CAPTURE AUTHORIZE).freeze
      ALLOWED_PAYMENT_TYPE        = %w(ONE_TIME RECURRING UNSCHEDULED).freeze
      ALLOWED_NETWORK             = %w(VISA MASTERCARD DISCOVER AMEX SOLO JCB STAR DELTA SWITCH MAESTRO CB_NATIONALE CONFIGOGA CONFIDIS ELECTRON CETELEM CHINA_UNION_PAY).freeze
      ALLOWED_TOKEN_TYPE          = %w(BILLING_AGREEMENT).freeze
      ALLOWED_PAYMENT_METHOD      = %w(PAYPAL).freeze


      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def base_url
        test? ? URLS[:test_url] : URLS[:live_url]
      end

      def commit(method, url, parameters = nil, options = {})
        response               = api_request(method, "#{ base_url }/#{ url }", parameters, options)
        success                = success_from(response)

        Response.new(
            success,
            message_from(success, response),
            response,
            authorization: authorization_from(response),
            avs_result: nil,
            cvv_result: nil,
            test: test?,
            error_code: error_code_from(response)
        )
      end

      # Prepare API request to hit remote endpoint \
      # to appropriate method(POST, GET, PUT, PATCH).
      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        parameters = parameters.nil? ? nil : parameters.to_json
        opt_headers.update(default_headers)
        begin
        raw_response = ssl_request(method, endpoint, parameters, opt_headers)
        response     = parse(raw_response)
        rescue ResponseError => e
        raw_response = e.response.body
        response     = response_error(raw_response)
        rescue JSON::ParserError
        response     = json_error(raw_response)
        end
        response
      end

      def encoded_credentials
        Base64.encode64("#{ @options[:authorization][:username] }:#{ @options[:authorization][:password] }").gsub("\n", "")
      end

      def default_headers
        return {
          "Content-Type"  => "application/json",
          "Authorization" => "Basic #{ encoded_credentials }"
        }
      end

      def parse(raw_response)
        raw_response = (raw_response.nil? || raw_response.empty?) ? "{}": raw_response
        JSON.parse(raw_response)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(response)
        return if success_from(response)
        code = response['name']
        code&.to_s
      end

      def message_from(success, response)
        success ? 'Transaction Successfully Completed' : response['message']
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the PayPal API. '
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
            'error' => {
                'message' => msg
            }
        }
      end

      def success_from(response)
        !response.key?('name') && response['debug_id'].nil? && !response.key?('error')
      end

      def supports_scrubbing?
        false
      end
    end
  end
end
