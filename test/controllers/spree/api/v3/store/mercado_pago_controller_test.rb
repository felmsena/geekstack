require "test_helper"

module Spree
  module Api
    module V3
      module Store
        class MercadoPagoControllerTest < ActionDispatch::IntegrationTest
          setup do
            @store = create_test_store
            @order = create_test_order(store: @store)
            @pm = create_mercado_pago_payment_method(
              store: @store,
              access_token: "TEST-TOKEN",
              success_url: "http://localhost:3001/checkout/success"
            )
            @api_key = create_publishable_api_key(store: @store)
          end

          test "creates a preference and a checkout payment" do
            stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
              .to_return(status: 201, body: { id: "pref_abc", init_point: "https://mp.example/checkout" }.to_json)

            post "/api/v3/store/carts/#{@order.to_param}/mercado_pago/preference",
                 headers: { "X-Spree-Api-Key" => @api_key.token }

            assert_response :success
            body = JSON.parse(response.body)
            assert_equal "https://mp.example/checkout", body["init_point"]
            assert_equal 1, @order.payments.where(state: "checkout").count
          end

          test "voids previous checkout payments before creating a new one" do
            stale_payment = @order.payments.create!(
              payment_method: @pm, amount: @order.total, response_code: "pref_old", state: "checkout"
            )

            stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
              .to_return(status: 201, body: { id: "pref_new", init_point: "https://mp.example/checkout" }.to_json)

            post "/api/v3/store/carts/#{@order.to_param}/mercado_pago/preference",
                 headers: { "X-Spree-Api-Key" => @api_key.token }

            assert_response :success
            stale_payment.reload
            assert_equal "void", stale_payment.state
          end

          test "rejects requests without a valid API key" do
            post "/api/v3/store/carts/#{@order.to_param}/mercado_pago/preference"

            assert_response :unauthorized
          end

          test "webhook accepts a request without X-Spree-Api-Key" do
            assert_enqueued_with(job: Spree::MercadoPago::WebhookJob, args: [ "123" ]) do
              post "/api/v3/store/mercado_pago/webhook", params: { type: "payment", data: { id: "123" } }
            end

            assert_response :success
          end

          test "webhook ignores non-payment topics" do
            assert_no_enqueued_jobs do
              post "/api/v3/store/mercado_pago/webhook", params: { type: "merchant_order", data: { id: "123" } }
            end

            assert_response :success
          end

          test "webhook rejects an invalid signature when a secret is configured" do
            @pm.preferred_webhook_secret = "shh"
            @pm.save!

            assert_no_enqueued_jobs do
              post "/api/v3/store/mercado_pago/webhook?data.id=123",
                   params: { type: "payment", data: { id: "123" } },
                   headers: { "x-signature" => "ts=1,v1=deadbeef", "x-request-id" => "req-1" }
            end

            assert_response :unauthorized
          end

          test "webhook accepts a valid signature when a secret is configured" do
            @pm.preferred_webhook_secret = "shh"
            @pm.save!

            ts = "1700000000"
            manifest = "id:123;request-id:req-1;ts:#{ts};"
            v1 = OpenSSL::HMAC.hexdigest("SHA256", "shh", manifest)

            assert_enqueued_with(job: Spree::MercadoPago::WebhookJob, args: [ "123" ]) do
              post "/api/v3/store/mercado_pago/webhook?data.id=123",
                   params: { type: "payment", data: { id: "123" } },
                   headers: { "x-signature" => "ts=#{ts},v1=#{v1}", "x-request-id" => "req-1" }
            end

            assert_response :success
          end
        end
      end
    end
  end
end
