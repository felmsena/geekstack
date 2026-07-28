require "test_helper"

class Spree::VariantTest < ActiveSupport::TestCase
  test "barcode is ransackable for exact-match lookup" do
    assert_includes Spree::Variant.whitelisted_ransackable_attributes, "barcode"
  end
end
