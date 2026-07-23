require "test_helper"

module Geekstack
  module MercadoPago
    class ProcessPaymentTest < ActiveSupport::TestCase
      setup do
        @store = create_test_store
        @order = create_test_order(store: @store, total: 0)
        product = create_test_product(store: @store, price: 5_000)
        add_line_item(order: @order, product: product, quantity: 2)
        @pm = create_mercado_pago_payment_method(store: @store, access_token: "TEST-TOKEN")
        @payment = @order.payments.create!(
          payment_method: @pm,
          amount: @order.total,
          response_code: "pref_123",
          state: "checkout"
        )
      end

      def stub_mp_payment(id:, status:, external_reference:, transaction_amount: 10_000)
        stub_request(:get, "https://api.mercadopago.com/v1/payments/#{id}")
          .to_return(
            status: 200,
            body: {
              id: id,
              status: status,
              external_reference: external_reference,
              transaction_amount: transaction_amount
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      test "completes the order's pending payment when MercadoPago reports approved" do
        stub_mp_payment(id: 999, status: "approved", external_reference: @order.number)

        ProcessPayment.new(mp_payment_id: 999, access_token: "TEST-TOKEN").call

        @payment.reload
        @order.reload
        assert_equal "completed", @payment.state
        assert_equal "999", @payment.response_code
      end

      test "voids the payment when MercadoPago reports rejected" do
        # The payment is still in Spree's "checkout" state at this point (we
        # never locally moved it to pending/processing), so "void" — not
        # "failure" — is the transition Spree's state machine actually allows.
        stub_mp_payment(id: 998, status: "rejected", external_reference: @order.number)

        ProcessPayment.new(mp_payment_id: 998, access_token: "TEST-TOKEN").call

        @payment.reload
        assert_equal "void", @payment.state
      end

      test "does nothing when no order matches the external_reference" do
        stub_mp_payment(id: 997, status: "approved", external_reference: "R000000000")

        assert_nothing_raised do
          ProcessPayment.new(mp_payment_id: 997, access_token: "TEST-TOKEN").call
        end

        @payment.reload
        assert_equal "checkout", @payment.state
      end

      test "does nothing when MercadoPago returns a non-200 response" do
        stub_request(:get, "https://api.mercadopago.com/v1/payments/996")
          .to_return(status: 404, body: { message: "not found" }.to_json)

        assert_nothing_raised do
          ProcessPayment.new(mp_payment_id: 996, access_token: "TEST-TOKEN").call
        end
      end

      test "does not raise on invalid JSON response" do
        stub_request(:get, "https://api.mercadopago.com/v1/payments/995")
          .to_return(status: 200, body: "not json")

        assert_nothing_raised do
          ProcessPayment.new(mp_payment_id: 995, access_token: "TEST-TOKEN").call
        end
      end

      test "does not raise on network timeout" do
        stub_request(:get, "https://api.mercadopago.com/v1/payments/994").to_timeout

        assert_nothing_raised do
          ProcessPayment.new(mp_payment_id: 994, access_token: "TEST-TOKEN").call
        end
      end

      test "matches the most recent pending MercadoPago payment, ignoring the preference_id" do
        # Regression test: the MercadoPago Payment resource has no preference_id
        # field, so matching must not depend on it.
        @payment.void!
        newer_payment = @order.payments.create!(
          payment_method: @pm,
          amount: @order.total,
          response_code: "pref_456",
          state: "checkout"
        )

        stub_mp_payment(id: 993, status: "approved", external_reference: @order.number)

        ProcessPayment.new(mp_payment_id: 993, access_token: "TEST-TOKEN").call

        newer_payment.reload
        assert_equal "completed", newer_payment.state
      end
    end
  end
end
