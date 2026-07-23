module Spree
  module Api
    module V3
      module Store
        class StockLocationsController < BaseController
          def index
            locations = Spree::StockLocation.active.map do |location|
              zone = Spree::Zone.find_by(description: "stock_location:#{location.id}")

              communes = if zone
                zone.zone_members.includes(:zoneable).map { |m| m.zoneable&.name }.compact.sort
              else
                []
              end

              {
                id: location.id,
                name: location.name,
                city: location.city,
                communes: communes
              }
            end

            render json: locations
          end
        end
      end
    end
  end
end
