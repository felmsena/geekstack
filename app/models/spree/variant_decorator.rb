# `barcode` exists as a column (distinct from `sku` — the code printed on a
# box isn't always the SKU) but isn't ransackable out of the box, so
# `q[barcode_eq]=...` 400s. Needed for the POS's barcode-scanner lookup.
module Spree::VariantDecorator
  def self.prepended(base)
    base.whitelisted_ransackable_attributes += %w[barcode]
  end
end

Spree::Variant.prepend(Spree::VariantDecorator)
