module Spree
  module MercadoPago
    class WebhookJob < ApplicationJob
      queue_as :default

      def perform(mp_payment_id)
        pm = Spree::PaymentMethod::MercadoPago.active.first
        return unless pm

        Geekstack::MercadoPago::ProcessPayment.new(
          mp_payment_id: mp_payment_id,
          access_token:  pm.preferred_access_token
        ).call
      end
    end
  end
end
