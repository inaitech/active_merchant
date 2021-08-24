require 'active_merchant/billing/gateways/paypal/paypal_checkout_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCheckoutGateway < Gateway
      include PaypalCheckoutCommon
      
      self.supported_countries = ['AU', 'AT', 'BE', 'BG', 'CA', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'GR', 'HU', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'US', 'GB']
      self.homepage_url        = 'https://www.paypal.com/us/business/platforms-and-marketplaces'
      self.display_name        = 'PayPal Commerce Platform'
      self.default_currency    = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb]

      def create_order(intent, options)
        requires!(options.merge!(intent.nil? ? {} : { intent: intent}), :intent, :purchase_units)

        post = {}
        add_intent(intent, post)
        add_purchase_units(options[:purchase_units], post)
        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].blank?
        add_application_context(options[:application_context], post) unless options[:application_context].blank?
        add_order_payer(options[:payer], post) unless options[:payer].blank?
        commit(:post, "v2/checkout/orders", post, options[:headers])
      end

      def authorize(order_id, options={})
        requires!({ order_id: order_id }, :order_id)

        post = {}
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        add_application_context(options[:application_context], post) unless options[:application_context].nil?
        commit(:post, "v2/checkout/orders/#{ order_id }/authorize", post, options[:headers])
      end

      def capture(order_id, options={})
        requires!({ order_id: order_id }, :order_id)

        post = {}
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        add_application_context(options[:application_context], post) unless options[:application_context].nil?
        commit(:post, "v2/checkout/orders/#{ order_id }/capture", post, options[:headers])
      end

      def refund(capture_id, options={})
        requires!({ capture_id: capture_id }, :capture_id)

        post = {}
        add_amount(options[:amount], post) unless options[:amount].nil?
        add_invoice(options[:invoice_id], post) unless options[:invoice_id].nil?
        add_note(options[:note_to_payer], post) unless options[:note_to_payer].nil?
        commit(:post, "v2/payments/captures/#{ capture_id }/refund", post, options[:headers])
      end

      def void(authorization_id, options={})
        requires!({ authorization_id: authorization_id }, :authorization_id)
        post = {}
        commit(:post, "v2/payments/authorizations/#{ authorization_id }/void", post, options[:headers])
      end

      def do_capture(authorization_id, options={})
        requires!(options.merge!({ authorization_id: authorization_id  }), :authorization_id)

        post = {}
        add_amount(options[:amount], post) unless options[:amount].nil?
        add_invoice(options[:invoice_id], post) unless options[:invoice_id].nil?
        add_final_capture(options[:final_capture], post) unless options[:final_capture].nil?
        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].nil?
        add_note(options[:note_to_payer], post) unless options[:note_to_payer].nil?

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/capture", post, options[:headers])
      end

      def get_order_details(order_id, options={})
        requires!(options.merge(order_id: order_id), :order_id)
        commit(:get, "v2/checkout/orders/#{ order_id }", nil, options[:headers])
      end

      def get_authorization_details(authorization_id, options={})
        requires!(options.merge(authorization_id: authorization_id), :authorization_id)
        commit(:get, "v2/payments/authorizations/#{ authorization_id }", nil, options[:headers])
      end

      def get_capture_details(capture_id, options={})
        requires!(options.merge(capture_id: capture_id), :capture_id)
        commit(:get, "v2/payments/captures/#{ capture_id }", nil, options[:headers])
      end

      def get_refund_details(refund_id, options={})
        requires!(options.merge(refund_id: refund_id), :refund_id)
        commit(:get, "v2/payments/refunds/#{ refund_id }", nil, options[:headers])
      end

      private

      def add_purchase_units(options, post)
        post[:purchase_units] = []
        options.map do |purchase_unit|
          post[:purchase_units] << add_purchase_unit(purchase_unit)
        end
        post
      end

      def add_purchase_unit(purchase_unit)
        requires!(purchase_unit, :amount)
        purchase_unit_hsh = {}
        purchase_unit_hsh[:reference_id]    = purchase_unit[:reference_id] unless purchase_unit[:reference_id].nil?
        purchase_unit_hsh[:description]     = purchase_unit[:description] unless purchase_unit[:description].nil?
        purchase_unit_hsh[:shipping_method] = purchase_unit[:shipping_method] unless purchase_unit[:shipping_method].nil?
        purchase_unit_hsh[:payment_group_id]= purchase_unit[:payment_group_id] unless purchase_unit[:payment_group_id].nil?
        purchase_unit_hsh[:custom_id]       = purchase_unit[:custom_id] unless purchase_unit[:custom_id].nil?
        purchase_unit_hsh[:invoice_id]      = purchase_unit[:invoice_id] unless purchase_unit[:invoice_id].nil?
        purchase_unit_hsh[:soft_descriptor] = purchase_unit[:soft_descriptor] unless purchase_unit[:soft_descriptor].nil?

        add_amount(purchase_unit[:amount], purchase_unit_hsh)
        add_payee(purchase_unit[:payee], purchase_unit_hsh) unless purchase_unit[:payee].nil?
        add_items(purchase_unit[:items], purchase_unit_hsh) unless purchase_unit[:items].nil?
        add_shipping(purchase_unit[:shipping], purchase_unit_hsh) unless purchase_unit[:shipping].nil?
        add_payment_instruction(purchase_unit[:payment_instruction], purchase_unit_hsh) unless purchase_unit[:payment_instruction].blank?
        purchase_unit_hsh
      end

      def add_application_context(options, post)
        post[:application_context] = {}
        post[:application_context][:return_url]          = options[:return_url] unless options[:return_url].nil?
        post[:application_context][:cancel_url]          = options[:cancel_url] unless options[:cancel_url].nil?
        post[:application_context][:landing_page]        = options[:landing_page] unless options[:landing_page].nil? || !ALLOWED_LANDING_PAGE.include?(options[:landing_page])
        post[:application_context][:locale]              = options[:locale] unless options[:locale].nil?
        post[:application_context][:user_action]         = options[:user_action] unless options[:user_action].nil? || !ALLOWED_USER_ACTION.include?(options[:user_action])
        post[:application_context][:brand_name]          = options[:brand_name] unless options[:brand_name].nil?
        post[:application_context][:shipping_preference] = options[:shipping_preference] unless options[:shipping_preference].nil? || !ALLOWED_SHIPPING_PREFERENCE.include?(options[:shipping_preference])

        add_payment_method(options[:payment_method], post) unless options[:payment_method].nil?
        add_stored_payment_source(options[:stored_payment_source], post) unless options[:stored_payment_source].nil?
        skip_empty(post, :application_context)
      end

      def add_stored_payment_source(options, post)
        requires!(options, :payment_initiator, :payment_type)
        post[:stored_payment_source] = {}
        post[:stored_payment_source][:payment_initiator] = options[:payment_initiator] if ALLOWED_PAYMENT_INITIATOR.include?(options[:payment_initiator])
        post[:stored_payment_source][:payment_type]      = options[:payment_type] if ALLOWED_PAYMENT_TYPE.include?(options[:payment_type])
        post[:stored_payment_source][:usage]             = options[:usage] if ALLOWED_USAGE.include?(options[:usage])
        add_network_transaction_reference(options[:previous_network_transaction_reference], post)
        skip_empty(post, :stored_payment_source)
      end

      def add_network_transaction_reference(options, post)
        requires!(options, :id, :network)
        post[:previous_network_transaction_reference] = {}
        post[:previous_network_transaction_reference][:id]      = options[:id]
        post[:previous_network_transaction_reference][:date]    = options[:date]
        post[:previous_network_transaction_reference][:network] = options[:network] if ALLOWED_NETWORK.include?(options[:network])
        post
      end

      def add_payment_method(options, post)
        post[:payment_method] = {}
        post[:payment_method][:payer_selected]            = options[:payer_selected]
        post[:payment_method][:payee_preferred]           = options[:payee_preferred] if ALLOWED_PAYEE_PREFERRED.include?(options[:payee_preferred])
        post[:payment_method][:standard_entry_class_code] = options[:standard_entry_class_code] if ALLOWED_STANDARD_ENTRIES.include?(options[:standard_entry_class_code])
        skip_empty(post, :payment_method)
      end

      def add_payment_instruction(options, post, key=:payment_instruction)
        post[key]                     = {}
        post[key][:platform_fees]     = []
        post[key][:disbursement_mode] = options[:disbursement_mode] unless options[:disbursement_mode].nil? || !ALLOWED_DISBURSEMENT_MODE.include(options[:disbursement_mode])

        options[:platform_fees].map do |platform_fee|
          requires!(platform_fee, :amount, :payee)
          platform_fee_hsh = {}
          add_amount(platform_fee[:amount], platform_fee_hsh)
          add_payee(platform_fee[:payee], platform_fee_hsh)
          post[key][:platform_fees] << platform_fee_hsh
        end
        skip_empty(post, key)
      end

      def add_intent(intent, post)
        post[:intent]  = intent if ALLOWED_INTENT.include?(intent)
        post
      end

      def add_payee(payee_obj, obj_hsh)
        obj_hsh[:payee] = {}
        obj_hsh[:payee][:merchant_id]   = payee_obj[:merchant_id] unless payee_obj[:merchant_id].nil?
        obj_hsh[:payee][:email_address] = payee_obj[:email_address] unless payee_obj[:email_address].nil?
        skip_empty(obj_hsh, :payee)
      end

      def add_amount(amount, post, key=:amount)
        requires!(amount, :currency_code, :value)

        post[key] = {}
        post[key][:currency_code] = amount[:currency_code] || currency(amount[:value])
        post[key][:value]         = amount[:value]

        add_breakdown_for_amount(amount[:breakdown], post, key) unless amount[:breakdown].blank?
        post
      end

      def add_breakdown_for_amount(options, post, key)
        post[key][:breakdown] = {}
        options.each do |item, _|
            add_amount(options[item], post[key][:breakdown], item)
        end
        skip_empty(post[key], :breakdown)
      end

      def add_items(options, post)
        post[:items] = []

        options.each do |item|
          requires!(item, :name, :quantity, :unit_amount)

          items_hsh = {}
          items_hsh[:name]        = item[:name]
          items_hsh[:sku]         = item[:sku] unless item[:sku].nil?
          items_hsh[:quantity]    = item[:quantity]
          items_hsh[:description] = item[:description]
          items_hsh[:category]    = item[:category] unless item[:category].nil? || !ALLOWED_ITEM_CATEGORY.include?(item[:category])

          add_amount(item[:unit_amount], items_hsh, :unit_amount)
          add_amount(item[:tax], items_hsh, :tax) unless item[:tax].nil?

          post[:items] << items_hsh
        end
        post
      end

      def add_shipping(options, post)
        post[:shipping]           = {}
        post[:shipping][:address] = {}
        add_name(options[:name], post[:shipping]) unless options[:name].nil?
        add_shipping_address(options[:address], post[:shipping]) unless options[:address].nil?
        skip_empty(post, :shipping)
      end

      def skip_empty(obj_hsh, key)
        obj_hsh.delete(key) if obj_hsh[key].empty?
      end

      def add_name(options, post, key=:name)
        post[key] = {}
        post[key][:full_name] = options[:full_name]
        skip_empty(post[key], :full_name)
      end

      def add_shipping_address(address, obj_hsh, key = :address)
        requires!(address, :admin_area_2, :postal_code, :country_code )

        obj_hsh[key] = {}
        obj_hsh[key][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[key][:address_line_2] = address[:address_line_2] unless address[:address_line_2].nil?
        obj_hsh[key][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[key][:admin_area_2]   = address[:admin_area_2]
        obj_hsh[key][:postal_code]    = address[:postal_code]
        obj_hsh[key][:country_code]   = address[:country_code]
        obj_hsh
      end

      def add_billing_address(address, obj_hsh)
        requires!(address, :country_code )

        obj_hsh[:billing_address] = {}
        obj_hsh[:billing_address][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[:billing_address][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[:billing_address][:admin_area_2]   = address[:admin_area_2] unless address[:admin_area_2].nil?
        obj_hsh[:billing_address][:postal_code]    = address[:postal_code] unless address[:postal_code].nil?
        obj_hsh[:billing_address][:country_code]   = address[:country_code] unless address[:country_code].nil?
        obj_hsh
      end

      def add_invoice(invoice_id, post)
        post[:invoice_id]  = invoice_id
        post
      end

      def add_final_capture(final_capture, post)
        post[:final_capture] = final_capture
        post
      end

      def add_note(note, post)
        post[:note_to_payer] = note
        post
      end

      def add_payment_source(source, post)
        post[:payment_source] = {}
        add_customer_card(source[:card], post[:payment_source]) unless source[:card].nil?
        add_token(source[:token], post[:payment_source]) unless source[:token].nil?
        skip_empty(post, :payment_source)
      end

      def add_customer_card(card_details, post)
        requires!(card_details, :number, :expiry, :name, :security_code)

        post[:card] = {}
        post[:card][:name]          = card_details[:name]
        post[:card][:number]        = card_details[:number]
        post[:card][:expiry]        = card_details[:expiry]
        post[:card][:security_code] = card_details[:security_code]
        add_billing_address(card_details[:billing_address], post) unless card_details[:billing_address].nil?
        verify_card(post[:card])
        post
      end

      def verify_card(card)
        defaults = {
            number: card[:number],
            first_name: card[:name],
            last_name: card[:name],
            verification_value: card[:security_code],
            month: card[:expiry].split("-")[1].to_i,
            year: card[:expiry].split("-")[0].to_i
        }
        @visa_card = ActiveMerchant::Billing::CreditCard.new(defaults)
        raise "Invalid Credit Card Format. Message: Missing #{@visa_card.validate}" unless @visa_card.validate.empty?
      end

      def add_token(options, post)
        requires!(options, :id, :type)
        post[:token] = {}
        post[:token][:id]   = options[:id]
        post[:token][:type] = options[:type] if ALLOWED_TOKEN_TYPE.include?(options[:type])
        post
      end

      def add_order_payer(options, post)
        post[:payer] = {}
        post[:payer][:email_address] = options[:email_address]
        post[:payer][:payer_id]      = options[:payer_id]
        post[:payer][:birth_date]    = options[:birth_date]

        add_payer_name(options[:name], post)
        add_phone_number(options[:phone], post)
        add_tax_info(options[:tax_info], post)
        add_address(options[:address], post)
      end

      def add_phone_number(options, post)
        post[:phone] = {}
        post[:phone][:phone_type]   = options[:phone_type] if ALLOWED_PHONE_TYPE.include?(options[:phone_type])
        post[:phone][:phone_number] = {}
        post[:phone][:phone_number][:national_number] = options[:phone_number][:national_number]
        post
      end

      def add_tax_info(options, post)
        post[:tax_info]               = {}
        post[:tax_info][:tax_id]      = options[:tax_id]
        post[:tax_info][:tax_id_type] = options[:tax_id_type] if ALLOWED_TAX_TYPE.include?(options[:tax_id_type])
        post
      end

      def add_address(options, post)
        post[:address] = {}
        post[:address][:address_line_1] = options[:address_line_1]
        post[:address][:address_line_2] = options[:address_line_2]
        post[:address][:admin_area_2]   = options[:admin_area_2]
        post[:address][:admin_area_1]   = options[:admin_area_1]
        post[:address][:postal_code]    = options[:postal_code]
        post[:address][:country_code]   = options[:country_code]
        post
      end

      def add_payer_name(options, post)
        post[:name] = {}
        post[:name][:given_name] = options[:given_name]
        post[:name][:surname]    = options[:surname]
        post
      end
    end
  end
end