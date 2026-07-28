# Exposed on both Store and Admin customer responses since
# Admin::CustomerSerializer inherits from this base class.
module Spree::Api::V3::CustomerSerializerDecorator
  def self.prepended(base)
    base.attributes :rut
  end
end

Spree::Api::V3::CustomerSerializer.prepend(Spree::Api::V3::CustomerSerializerDecorator)
