require "test_helper"

module Spree
  module Api
    module V3
      module Store
        class StockLocationsControllerTest < ActionDispatch::IntegrationTest
          setup do
            @store = create_test_store
            @api_key = create_publishable_api_key(store: @store)
          end

          test "returns each active stock location with its communes" do
            location, = create_test_stock_location_with_commune(commune_name: "Providencia")

            get "/api/v3/store/stock_locations", headers: { "X-Spree-Api-Key" => @api_key.token }

            assert_response :success
            body = JSON.parse(response.body)
            entry = body.find { |l| l["id"] == location.id }

            assert entry
            assert_equal [ "Providencia" ], entry["communes"]
          end

          test "returns an empty communes list for a location without a zone" do
            location = Spree::StockLocation.create!(name: "No Zone Store", active: true)

            get "/api/v3/store/stock_locations", headers: { "X-Spree-Api-Key" => @api_key.token }

            assert_response :success
            entry = JSON.parse(response.body).find { |l| l["id"] == location.id }

            assert_equal [], entry["communes"]
          end

          test "does not include inactive stock locations" do
            location = Spree::StockLocation.create!(name: "Inactive Store", active: false)

            get "/api/v3/store/stock_locations", headers: { "X-Spree-Api-Key" => @api_key.token }

            assert_response :success
            refute JSON.parse(response.body).any? { |l| l["id"] == location.id }
          end
        end
      end
    end
  end
end
