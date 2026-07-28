# Presencial (POS) sales are legitimately anonymous — a walk-in customer can
# decline to leave their details, and we'd rather allow that than force a
# placeholder email that pollutes customer data. Spree's own require_email
# blocks any order past cart/address/delivery state without one; POS orders
# start at "draft" (see Spree::Orders::Create), so this exemption is required
# for a second save (e.g. adding a payment) to succeed at all.
module Spree::OrderDecorator
  def self.prepended(base)
    # Shipping rates are computed per-Zone from ship_address, so a POS order
    # with no address at all never gets a shipment and 422s on complete
    # ("no podemos enviar ... a tu ubicación actual") — even though "Retiro en
    # tienda" doesn't actually need one. Fill it from the fulfilling store's
    # own address so zone matching succeeds without asking a walk-in customer
    # for anything. `quick_checkout: true` skips Address's
    # firstname/lastname/street/zipcode presence validations (see
    # Spree::Address#require_name?/#require_street?/#require_zipcode?), so a
    # bare country+state+city is enough here.
    base.before_validation :assign_pickup_address_for_pos, on: :create
  end

  private

  def require_email
    return false if channel&.code == Geekstack::PosChannel::CODE

    super
  end

  def assign_pickup_address_for_pos
    return unless channel&.code == Geekstack::PosChannel::CODE
    return unless preferred_stock_location

    pickup_address = preferred_stock_location.address
    pickup_address.quick_checkout = true

    self.ship_address ||= pickup_address
    self.bill_address ||= pickup_address
  end
end

Spree::Order.prepend(Spree::OrderDecorator)
