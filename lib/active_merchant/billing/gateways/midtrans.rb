begin
  require 'veritrans'
rescue LoadError
  raise 'Could not load the veritrans gem.  Use `gem install veritrans` to install it.'
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MidtransGateway < Gateway
      self.test_url = 'https://api.sandbox.midtrans.com/v2'
      self.live_url = 'https://api.midtrans.com/v2'
      self.supported_countries = ['ID']
      self.default_currency = 'IDR'
      self.supported_cardtypes = [:visa, :master, :jcb, :american_express]
      self.homepage_url = 'https://midtrans.com/'
      self.display_name = 'Midtrans'

      SUPPORTED_PAYMENT_METHODS = [:credit_card, :bank_transfer, :echannel,
         :bca_klikpay, :bca_klikbca, :mandiri_clickpay, :bri_epay, :cimb_clicks,
         :telkomsel_cash, :xl_tunai, :indosat_dompetku, :mandiri_ecash, :cstor]

      STATUS_CODE_MAPPING = {
        sucess: 200,
        pending_or_challenge: 201,
        denied: 202,

        move_permanently: 300,

        validation_error: 400,
        access_denied: 401,
        payment_type_access_denined: 402,
        invalid_content_header: 403,
        resouce_not_found: 404,
        http_method_not_allowed: 405,
        duplicated_order_id: 406,
        expired_transaction: 407,
        wrong_data_type: 408,
        too_much_transactions: 409,
        account_deactivated: 410,
        token_error: 411,
        cannot_modify_transaction_status: 412,
        malformed_syntax_error: 413,

        internal_server_error: 500,
        feature_unavailable: 501,
        bank_connection_problem: 502,
        service_unavailable: 503,
        fraud_detections_unavailable: 504
      }

      TRANSACTION_STATUS_MAPPING = {
        capture: 'capture',
        deny: 'deny',
        authorize: 'authorize',
        cancel: 'cancel',
        expire: 'expire'
      }

      MINIMUM_AUTHORIZE_AMOUNTS = {
        'IDR' => 50
      }

      FRAUD_STATUS_MAPPING = {
        accept: 'accept',
        challenge: 'challenge',
        deny: 'deny'
      }

      def initialize(options={})
        requires!(options, :client_key, :server_key)
        super
        @midtrans_gateway = Midtrans
        @midtrans_gateway.config.client_key = options[:client_key]
        @midtrans_gateway.config.server_key = options[:server_key]
        @midtrans_gateway.logger = options[:logger]
      end

      def authorize(money, payment, options={})
        payment[:credit_card][:type] = TRANSACTION_STATUS_MAPPING[:authorize]
        purchase(money, payment, options)
      end

      def capture(money, authorization, options={})
        post = {}
        add_authorization(post, money, authorization)

        begin
          gateway_response = @midtrans_gateway.capture(*post.values)
          response_for(gateway_response)
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)

        commit('charge', post)
      end

      def approve(payment, options = {})
        begin
          gateway_response = @midtrans_gateway.approve(payment, options)
          response_for(gateway_response)
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def void(authorization, options={})
        begin
          gateway_response = @midtrans_gateway.cancel(authorization, options)
          response_for(gateway_response)
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def status(authorization)
        begin
          gateway_response = @midtrans_gateway.status(authorization)
          response_for(gateway_response)
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def verify(payment, options = {})
        MultiResponse.run do |r|
          r.process { authorize(auth_minimum_amount(options), payment, options) }
          r.process { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
        post[:customer_details] = options['customer_details']
      end

      def add_address(post, options)
        customer_details = post[:customer_details] = {}
        customer_details[:billing_address] = options[:billing_address]
        customer_details[:shipping_address] = options[:shipping_address] || options[:billing_address]
      end

      def add_invoice(post, money, options)
        post[:transaction_details] = {
          gross_amount: money,
          order_id: options[:order_id]
        }
        post[:item_details] = options[:item_details]
      end

      def add_payment(post, payment)
        payment_type = payment[:payment_type]
        post[:payment_type] = payment_type
        # post[payment_type.to_sym] = payment[payment_type.to_sym]
        credit_card = payment[:credit_card][:card]
        @uri = URI.parse(
          "https://api.sandbox.veritrans.co.id/v2/token?card_number=#{credit_card[:number]}&card_cvv=#{credit_card[:cvv]}&card_exp_month=#{credit_card[:expiry_month]}&card_exp_year=#{credit_card[:expiry_year]}&client_key=#{@midtrans_gateway.config.client_key}"
        )
        response = Net::HTTP.get_response(@uri)
        p JSON.parse(response.body)["token_id"]
        post[:credit_card] = {}
        post[:credit_card][:token_id] = JSON.parse(response.body)["token_id"]
      end

      def add_authorization(post, money, authorization)
        post[:transaction_id] = authorization
        post[:gross_amount] = money
      end

      def commit(action, parameters)
        begin
          gateway_response = @midtrans_gateway.public_send(action.to_sym, parameters)
          response_for(gateway_response)
        rescue ResponseError => e
          Response.new(false, e.response.message)
        end
      end

      def auth_minimum_amount(options)
        return 100 unless options[:currency]
        return MINIMUM_AUTHORIZE_AMOUNTS[options[:currency].upcase] || 100
      end

      def success_from(gateway_response)
        gateway_response.success?
      end

      def message_from(gateway_response)
        gateway_response.status_message
      end

      def authorization_from(gateway_response)
        gateway_response.transaction_id
      end

      def response_for(gateway_response)
        Response.new(
          success_from(gateway_response),
          message_from(gateway_response),
          gateway_response.data,
          status_code: gateway_response.status_code,
          authorization: authorization_from(gateway_response),
          test: test?
        )
      end
    end
  end
end
