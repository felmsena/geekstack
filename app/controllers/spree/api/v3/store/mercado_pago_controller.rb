module Spree
  module Api
    module V3
      module Store
        class MercadoPagoController < BaseController
          # MercadoPago never sends X-Spree-Api-Key. Authenticity for this
          # action is verified via the x-signature HMAC instead.
          skip_before_action :authenticate_api_key!, only: :webhook, raise: false

          # POST /api/v3/store/carts/:cart_id/mercado_pago/preference
          def create_preference
            cart = Spree::Order.find_by_prefix_id!(params[:cart_id])
            pm   = Spree::PaymentMethod::MercadoPago.active.first

            return render json: { error: "Payment method not configured" }, status: :unprocessable_entity unless pm

            result = Geekstack::MercadoPago::CreatePreference.new(order: cart, payment_method: pm).call

            if result[:success]
              void_pending_payments(cart, pm)

              cart.payments.create!(
                payment_method: pm,
                amount:         cart.total,
                response_code:  result[:preference_id],
                state:          "checkout"
              )
              render json: { init_point: result[:init_point], preference_id: result[:preference_id] }
            else
              render json: { error: result[:error] }, status: :unprocessable_entity
            end
          end

          # POST /api/v3/store/mercado_pago/webhook
          # MercadoPago sends two formats — old (topic/id) and new (type/data.id)
          def webhook
            payment_id = params.dig(:data, :id) || params[:id]
            topic      = params[:type] || params[:topic]

            head :ok and return if payment_id.blank? || topic.to_s != "payment"
            head :unauthorized and return unless valid_webhook_signature?

            Spree::MercadoPago::WebhookJob.perform_later(payment_id.to_s)
            head :ok
          end

          private

          # Voids any payment attempt left in "checkout" so a customer who
          # retries MercadoPago doesn't accumulate stale duplicate payments.
          def void_pending_payments(cart, pm)
            cart.payments.where(payment_method: pm, state: "checkout").find_each do |payment|
              payment.void! if payment.can_void?
            end
          end

          # Validates MercadoPago's HMAC-SHA256 webhook signature.
          # https://www.mercadopago.com/developers/en/docs/your-integrations/notifications/webhooks
          def valid_webhook_signature?
            secret = Spree::PaymentMethod::MercadoPago.active.first&.preferred_webhook_secret
            if secret.blank?
              Rails.logger.warn("[MercadoPago] webhook_secret not configured — skipping signature check")
              return true
            end

            signature = request.headers["x-signature"]
            request_id = request.headers["x-request-id"]
            data_id = request.query_parameters["data.id"] || params[:id]
            return false if signature.blank? || request_id.blank? || data_id.blank?

            parts = signature.split(",").filter_map { |p| p.split("=", 2) }.to_h
            ts, v1 = parts["ts"], parts["v1"]
            return false if ts.blank? || v1.blank?

            manifest = "id:#{data_id};request-id:#{request_id};ts:#{ts};"
            expected = OpenSSL::HMAC.hexdigest("SHA256", secret, manifest)

            ActiveSupport::SecurityUtils.secure_compare(expected, v1)
          end
        end
      end
    end
  end
end
