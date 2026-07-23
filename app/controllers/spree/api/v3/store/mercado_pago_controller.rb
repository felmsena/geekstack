module Spree
  module Api
    module V3
      module Store
        class MercadoPagoController < BaseController
          # POST /api/v3/store/carts/:cart_id/mercado_pago/preference
          def create_preference
            cart = Spree::Order.find_by_prefix_id!(params[:cart_id])
            pm   = Spree::PaymentMethod::MercadoPago.active.first

            return render json: { error: "Payment method not configured" }, status: :unprocessable_entity unless pm

            result = Geekstack::MercadoPago::CreatePreference.new(order: cart, payment_method: pm).call

            if result[:success]
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

            Spree::MercadoPago::WebhookJob.perform_later(payment_id.to_s)
            head :ok
          end
        end
      end
    end
  end
end
