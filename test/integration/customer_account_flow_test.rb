require "test_helper"

# Coverage for the 4a account flows verified live against a running server:
# password reset (via letter_opener in dev, see config/environments/development.rb),
# guest cart -> customer association, and saved customer addresses.
class CustomerAccountFlowTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_test_store
    @api_key = create_publishable_api_key(store: @store)
    @headers = { "X-Spree-Api-Key" => @api_key.token }
    @user = create_test_customer
  end

  test "requests and completes a password reset" do
    post "/api/v3/store/password_resets", params: { email: @user.email }, headers: @headers
    assert_response :accepted

    token = @user.generate_token_for(:password_reset)
    patch "/api/v3/store/password_resets/#{ERB::Util.url_encode(token)}",
          params: { password: "newpassword123", password_confirmation: "newpassword123" },
          headers: @headers
    assert_response :success

    body = JSON.parse(response.body)
    assert body["token"].present?
    assert @user.reload.valid_password?("newpassword123")
  end

  test "unknown email still returns 202 (no account enumeration)" do
    post "/api/v3/store/password_resets", params: { email: "nobody@example.com" }, headers: @headers
    assert_response :accepted
  end

  test "associates a guest cart with the authenticated customer" do
    post "/api/v3/store/carts", headers: @headers
    cart = JSON.parse(response.body)

    post "/api/v3/store/auth/login", params: { email: @user.email, password: "password123" }, headers: @headers
    assert_response :success
    jwt = JSON.parse(response.body)["token"]

    patch "/api/v3/store/carts/#{cart['id']}/associate",
          headers: @headers.merge("x-spree-token" => cart["token"], "Authorization" => "Bearer #{jwt}")
    assert_response :success
    assert_equal @user.email, JSON.parse(response.body)["email"]
  end

  test "manages saved customer addresses without a postal code" do
    create_test_stock_location_with_commune(commune_name: "Providencia")

    post "/api/v3/store/auth/login", params: { email: @user.email, password: "password123" }, headers: @headers
    auth_headers = @headers.merge("Authorization" => "Bearer #{JSON.parse(response.body)['token']}")

    post "/api/v3/store/customers/me/addresses",
         params: {
           first_name: "Ada", last_name: "Lovelace", address1: "Av. Siempre Viva 123",
           city: "Providencia", country_iso: "CL", state_name: "Providencia", phone: "+56900000000"
         },
         headers: auth_headers
    assert_response :created
    address = JSON.parse(response.body)
    assert_nil address["postal_code"]

    get "/api/v3/store/customers/me/addresses", headers: auth_headers
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["data"].size

    patch "/api/v3/store/customers/me/addresses/#{address['id']}",
          params: { is_default_shipping: true }, headers: auth_headers
    assert_response :success
    assert JSON.parse(response.body)["is_default_shipping"]

    delete "/api/v3/store/customers/me/addresses/#{address['id']}", headers: auth_headers
    assert_response :no_content
  end
end
