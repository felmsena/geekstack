require "test_helper"

class Geekstack::ChileRegionsTest < ActiveSupport::TestCase
  test "has the 16 official regions and 346 comunas, no name collisions" do
    regions = Geekstack::ChileRegions::REGIONS

    assert_equal 16, regions.size
    assert_equal 346, Geekstack::ChileRegions::TOTAL_COMUNAS

    all_comunas = regions.values.flatten
    assert_equal all_comunas.size, all_comunas.uniq.size, "comuna names must be unique across regions"
  end
end
