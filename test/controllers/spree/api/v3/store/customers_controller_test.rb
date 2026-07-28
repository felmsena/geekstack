require "test_helper"

module Spree
  module Api
    module V3
      module Store
        class CustomersControllerTest < ActionDispatch::IntegrationTest
          setup do
            @store = create_test_store
            @api_key = create_publishable_api_key(store: @store)
          end

          def register(rut:)
            post "/api/v3/store/customers",
                 params: {
                   email: "buyer_#{SecureRandom.hex(4)}@example.com",
                   password: "password123",
                   password_confirmation: "password123",
                   rut: rut
                 },
                 headers: { "X-Spree-Api-Key" => @api_key.token }
          end

          test "registers a customer with a valid rut" do
            register(rut: "12.345.678-5")

            assert_response :success
            body = JSON.parse(response.body)
            assert_equal "12345678-5", body["user"]["rut"]
          end

          test "rejects registration without a rut" do
            post "/api/v3/store/customers",
                 params: { email: "buyer@example.com", password: "password123", password_confirmation: "password123" },
                 headers: { "X-Spree-Api-Key" => @api_key.token }

            assert_response :unprocessable_content
            body = JSON.parse(response.body)
            assert_includes body["error"]["details"]["rut"], "no puede estar en blanco"
          end

          test "rejects registration with an invalid rut check digit" do
            register(rut: "11111111-2")

            assert_response :unprocessable_content
            body = JSON.parse(response.body)
            assert_includes body["error"]["details"]["rut"], "no es un RUT chileno válido"
          end
        end
      end
    end
  end
end
