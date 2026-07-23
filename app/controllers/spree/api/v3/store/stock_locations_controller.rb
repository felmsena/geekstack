module Spree
  module Api
    module V3
      module Store
        class StockLocationsController < BaseController
          def index
            zones_by_location_id = Spree::Zone.where("description LIKE ?", "#{Geekstack::StoreZone::PREFIX}%")
                                               .includes(zone_members: :zoneable)
                                               .index_by { |zone| Geekstack::StoreZone.location_id_from(zone.description) }

            locations = Spree::StockLocation.active.map do |location|
              zone = zones_by_location_id[location.id]
              communes = zone ? zone.zone_members.filter_map { |m| m.zoneable&.name }.sort : []

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
