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

        payment = find_payment(order)
        return unless payment

        payment.log_entries.create!(details: mp_payment.to_json)

        case mp_payment["status"]
        when "approved"
          payment.update!(amount: mp_payment["transaction_amount"], response_code: mp_payment["id"].to_s)
          payment.complete! if payment.can_complete?
          order.next! if order.can_next? && order.payment_state != "paid"
        when "rejected", "cancelled"
          # The payment never left Spree's "checkout" state (we only create it
          # locally, MercadoPago processes it externally), and the "failure"
          # transition only accepts pending/processing as a source state.
          # "void" is the transition that's actually reachable from "checkout".
          payment.void! if payment.can_void?
        end
      end

      private

      # The MercadoPago Payment resource has no `preference_id` field, so we
      # can't match on it. Instead, match the order's most recent MercadoPago
      # payment still awaiting confirmation.
      def find_payment(order)
        order.payments
             .where(payment_method_id: Spree::PaymentMethod::MercadoPago.pluck(:id))
             .where(state: %w[checkout pending])
             .order(created_at: :desc)
             .first
      end

      def fetch_payment
        uri = URI("#{MP_API}/v1/payments/#{@mp_payment_id}")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{@access_token}"

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |h| h.request(req) }
        return nil unless res.code.to_i == 200

        JSON.parse(res.body)
      rescue JSON::ParserError => e
        Rails.logger.error("[MercadoPago] fetch_payment: invalid JSON — #{e.message}")
        nil
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        Rails.logger.error("[MercadoPago] fetch_payment: network error — #{e.class}: #{e.message}")
        nil
      end
    end
  end
end
