require "test_helper"

module Geekstack
  module MercadoPago
    class CreatePreferenceTest < ActiveSupport::TestCase
      setup do
        @store = create_test_store
        @order = create_test_order(store: @store)
        @pm = create_mercado_pago_payment_method(
          store: @store,
          access_token: "TEST-TOKEN",
          success_url: "http://localhost:3001/checkout/success",
          failure_url: "http://localhost:3001/checkout/failure",
          pending_url: "http://localhost:3001/checkout/pending"
        )
      end

      test "returns init_point and preference_id on success" do
        stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
          .to_return(
            status: 201,
            body: { id: "pref_123", init_point: "https://mp.example/checkout" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = CreatePreference.new(order: @order, payment_method: @pm).call

        assert result[:success]
        assert_equal "pref_123", result[:preference_id]
        assert_equal "https://mp.example/checkout", result[:init_point]
      end

      test "includes order line items in the payload" do
        product = create_test_product(store: @store, price: 12_345)
        add_line_item(order: @order, product: product, quantity: 2)

        stub = stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
          .with { |req|
            item = JSON.parse(req.body)["items"].first
            item["title"] == "Test Game" && item["quantity"] == 2 && item["unit_price"] == 12_345.0
          }
          .to_return(status: 201, body: { id: "pref_1", init_point: "x" }.to_json)

        CreatePreference.new(order: @order, payment_method: @pm).call

        assert_requested stub
      end

      test "disables auto_return when success_url points to localhost" do
        stub = stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
          .with { |req| JSON.parse(req.body)["auto_return"].nil? }
          .to_return(status: 201, body: { id: "pref_1", init_point: "x" }.to_json)

        CreatePreference.new(order: @order, payment_method: @pm).call

        assert_requested stub
      end

      test "enables auto_return when success_url is not localhost" do
        @pm.preferred_success_url = "https://geekstack.cl/checkout/success"
        @pm.save!

        stub = stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
          .with { |req| JSON.parse(req.body)["auto_return"] == "approved" }
          .to_return(status: 201, body: { id: "pref_1", init_point: "x" }.to_json)

        CreatePreference.new(order: @order, payment_method: @pm).call

        assert_requested stub
      end

      test "returns failure on a non-201 response" do
        stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
          .to_return(status: 400, body: { message: "bad request" }.to_json)

        result = CreatePreference.new(order: @order, payment_method: @pm).call

        refute result[:success]
        assert_equal "bad request", result[:error]
      end

      test "returns failure without raising on network timeout" do
        stub_request(:post, "https://api.mercadopago.com/checkout/preferences").to_timeout

        result = CreatePreference.new(order: @order, payment_method: @pm).call

        refute result[:success]
        assert_match(/mercado ?pago/i, result[:error])
      end

      test "returns failure without raising on invalid JSON response" do
        stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
          .to_return(status: 201, body: "not json")

        result = CreatePreference.new(order: @order, payment_method: @pm).call

        refute result[:success]
      end
    end
  end
end
