require "test_helper"

class Spree::Seeds::StatesTest < ActiveSupport::TestCase
  test "does not attempt to seed Chile at the region level" do
    country = Spree::Country.find_or_create_by!(iso: "CL") do |c|
      c.name = "Chile"
      c.iso_name = "CHILE"
      c.iso3 = "CHL"
      c.numcode = 152
      c.states_required = true
    end
    # A comuna sharing its name with a Chilean region (see
    # states_decorator.rb) — if the region-level seed ran, it would collide
    # on Spree::State's per-country name uniqueness and raise.
    Spree::State.find_or_create_by!(name: "Antofagasta", country: country) { |s| s.abbr = "ANTOFAGASTA" }

    assert_nothing_raised { Spree::Seeds::States.call }
    assert_equal 1, Spree::State.where(name: "Antofagasta", country: country).count
  end
end
