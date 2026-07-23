module Spree
  class PaymentMethod::MercadoPago < PaymentMethod
    preference :access_token, :string
    preference :public_key,   :string
    preference :success_url,  :string, default: ""
    preference :failure_url,  :string, default: ""
    preference :pending_url,  :string, default: ""
    preference :webhook_url,  :string, default: ""
    preference :webhook_secret, :string, default: ""

    def supports?(_source)
      true
    end

    def source_required?
      false
    end

    def auto_capture?
      false
    end

    def payment_source_class
      nil
    end

    def authorize(_amount, _source, _options = {})
      ::ActiveMerchant::Billing::Response.new(true, "MercadoPago pending redirect", {}, authorization: "mp_pending")
    end

    def purchase(_amount, _source, _options = {})
      ::ActiveMerchant::Billing::Response.new(true, "MercadoPago pending redirect", {}, authorization: "mp_pending")
    end

    def method_type
      "mercado_pago"
    end
  end
end
