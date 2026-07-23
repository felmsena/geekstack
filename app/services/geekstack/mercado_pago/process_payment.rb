require "net/http"
require "json"

module Geekstack
  module MercadoPago
    class ProcessPayment
      MP_API = "https://api.mercadopago.com"

      def initialize(mp_payment_id:, access_token:)
        @mp_payment_id = mp_payment_id
        @access_token  = access_token
      end

      def call
        mp_payment = fetch_payment
        return unless mp_payment

        order = Spree::Order.find_by(number: mp_payment["external_reference"])
        return unless order

        payment = order.payments.find_by(response_code: mp_payment["preference_id"])
        return unless payment

        case mp_payment["status"]
        when "approved"
          payment.update!(amount: mp_payment["transaction_amount"])
          payment.complete! if payment.may_complete?
          order.next! if order.may_next? && order.payment_state != "paid"
        when "rejected", "cancelled"
          payment.failure! if payment.may_failure?
        end
      end

      private

      def fetch_payment
        uri = URI("#{MP_API}/v1/payments/#{@mp_payment_id}")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{@access_token}"

        res  = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
        body = JSON.parse(res.body)

        res.code.to_i == 200 ? body : nil
      end
    end
  end
end
