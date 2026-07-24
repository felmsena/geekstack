require "test_helper"

# End-to-end coverage of the API v3 Store checkout flow that the Next.js
# frontend actually drives: cart -> item -> address -> delivery -> MercadoPago
# payment -> webhook confirmation -> completed order. Serves as living
# documentation of the flow described in CLAUDE.md.
class ApiV3CheckoutFlowTest < ActionDispatch::IntegrationTest
  setup do
    # Spree geocodes shipping addresses via Nominatim in a background job.
    stub_request(:get, /nominatim\.openstreetmap\.org/).to_return(status: 200, body: "[]")

    @store = create_test_store
    @location, @zone, @state = create_test_stock_location_with_commune(commune_name: "Providencia")
    @product = create_test_product(store: @store, price: 9_990)
    create_test_shipping_method(zone: @zone, shipping_category: @product.shipping_category)
    @pm = create_mercado_pago_payment_method(
      store: @store, access_token: "TEST-TOKEN", success_url: "http://localhost:3001/checkout/success"
    )
    @api_key = create_publishable_api_key(store: @store)
    @headers = { "X-Spree-Api-Key" => @api_key.token }
  end

  test "completes a full guest checkout via MercadoPago" do
    # 1. Create the cart
    post "/api/v3/store/carts", headers: @headers
    assert_response :success
    cart = JSON.parse(response.body)
    cart_id = cart["id"]
    order_number = cart["number"]
    token = cart["token"]
    @headers = @headers.merge("x-spree-token" => token)

    # 2. Add the product to the cart
    post "/api/v3/store/carts/#{cart_id}/items",
         params: { variant_id: @product.master.to_param, quantity: 2 }, headers: @headers
    assert_response :success

    # 3. Set email + shipping address (auto-advances address -> delivery)
    patch "/api/v3/store/carts/#{cart_id}",
          params: {
            email: "buyer@example.com",
            shipping_address: {
              first_name: "Ada", last_name: "Lovelace",
              address1: "Av. Siempre Viva 123", city: "Providencia", postal_code: "7500000",
              country_iso: "CL", state_abbr: @state.abbr, phone: "+56900000000"
            }
          }, headers: @headers
    assert_response :success
    cart_after_address = JSON.parse(response.body)
    # Spree auto-selects the cheapest delivery rate when building shipments,
    # so a single available shipping method advances straight to "payment".
    assert_equal "payment", cart_after_address["current_step"]

    # 4. Select the delivery rate (there is no GET fulfillments#index route —
    # fulfillments come embedded in the cart payload)
    fulfillments = cart_after_address["fulfillments"]
    assert_equal 1, fulfillments.size
    delivery_rate_id = fulfillments.first["delivery_rates"].first["id"]
    fulfillment_id = fulfillments.first["id"]

    patch "/api/v3/store/carts/#{cart_id}/fulfillments/#{fulfillment_id}",
          params: { selected_delivery_rate_id: delivery_rate_id }, headers: @headers
    assert_response :success
    cart_after_delivery = JSON.parse(response.body)
    assert_equal "payment", cart_after_delivery["current_step"]

    # 5. Create the MercadoPago preference (creates a checkout-state Payment)
    stub_request(:post, "https://api.mercadopago.com/checkout/preferences")
      .to_return(status: 201, body: { id: "pref_full_flow", init_point: "https://mp.example/checkout" }.to_json)

    post "/api/v3/store/carts/#{cart_id}/mercado_pago/preference", headers: @headers
    assert_response :success

    order = Spree::Order.find_by!(number: order_number)
    assert_equal 1, order.payments.where(state: "checkout").count

    # 6. MercadoPago approves the payment; webhook confirms it
    stub_request(:get, "https://api.mercadopago.com/v1/payments/mp_123")
      .to_return(
        status: 200,
        body: {
          id: "mp_123", status: "approved",
          external_reference: order.number, transaction_amount: order.total.to_f
        }.to_json
      )

    assert_enqueued_with(job: Spree::MercadoPago::WebhookJob, args: [ "mp_123" ]) do
      post "/api/v3/store/mercado_pago/webhook", params: { type: "payment", data: { id: "mp_123" } }
    end
    perform_enqueued_jobs

    order.reload
    assert_equal "completed", order.payments.order(:created_at).last.state
    assert_equal "complete", order.state
    assert_equal "paid", order.payment_state
  end
end
