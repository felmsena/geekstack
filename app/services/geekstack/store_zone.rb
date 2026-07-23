module Geekstack
  # A Spree::Zone tagged with a description in the form "stock_location:<id>"
  # represents the delivery area (a set of communes) for one physical store.
  # This is the single place that convention is encoded, so it isn't
  # duplicated as a string literal across controllers/seeds.
  class StoreZone
    PREFIX = "stock_location:".freeze

    def self.description_for(stock_location)
      "#{PREFIX}#{stock_location.id}"
    end

    def self.location_id_from(description)
      return nil unless description&.start_with?(PREFIX)

      description.delete_prefix(PREFIX).to_i
    end
  end
end
