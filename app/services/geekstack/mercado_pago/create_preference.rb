require "net/http"
require "json"

module Geekstack
  module MercadoPago
    class CreatePreference
      MP_API = "https://api.mercadopago.com"

      def initialize(order:, payment_method:)
        @order = order
        @pm    = payment_method
      end

      def call
        uri = URI("#{MP_API}/checkout/preferences")
        req = Net::HTTP::Post.new(uri)
        req["Authorization"] = "Bearer #{@pm.preferred_access_token}"
        req["Content-Type"]  = "application/json"
        req.body = payload.to_json

        res  = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |h| h.request(req) }
        body = JSON.parse(res.body)

        if res.code.to_i == 201
          { success: true, init_point: body["init_point"], preference_id: body["id"] }
        else
          { success: false, error: body["message"] || "MercadoPago error #{res.code}" }
        end
      rescue JSON::ParserError => e
        Rails.logger.error("[MercadoPago] create_preference: invalid JSON — #{e.message}")
        { success: false, error: "MercadoPago returned an invalid response" }
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        Rails.logger.error("[MercadoPago] create_preference: network error — #{e.class}: #{e.message}")
        { success: false, error: "Could not reach MercadoPago, please try again" }
      end

      private

      def payload
        {
          items: items,
          external_reference: @order.number,
          payer: payer,
          back_urls: {
            success: @pm.preferred_success_url,
            failure: @pm.preferred_failure_url,
            pending: @pm.preferred_pending_url
          },
          auto_return: (@pm.preferred_success_url.to_s.include?("localhost") ? nil : "approved"),
          notification_url: @pm.preferred_webhook_url.presence,
          statement_descriptor: "Geekstack"
        }.compact
      end

      def items
        @order.line_items.map do |li|
          {
            id:         li.variant.sku,
            title:      li.variant.product.name,
            quantity:   li.quantity,
            unit_price: li.price.to_f,
            currency_id: @order.currency
          }
        end
      end

      def payer
        {
          email:   @order.email,
          name:    @order.ship_address&.first_name,
          surname: @order.ship_address&.last_name
        }.compact
      end
    end
  end
end
