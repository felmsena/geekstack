require "test_helper"

class Spree::OrderTest < ActiveSupport::TestCase
  setup do
    @store = create_test_store
    @country = Spree::Country.find_or_create_by!(iso: "CL") do |c|
      c.name = "Chile"
      c.iso_name = "CHILE"
      c.iso3 = "CHL"
      c.numcode = 152
      c.states_required = true
    end
    @state = Spree::State.find_or_create_by!(name: "Providencia", country: @country) { |s| s.abbr = "PROVIDENCIA" }
    @stock_location = Spree::StockLocation.create!(
      name: "Test POS Location", active: true, country: @country, state: @state,
      address1: "Av. Test 123", city: "Santiago"
    )
    @channel = Spree::Channel.find_or_create_by!(code: Geekstack::PosChannel::CODE) do |c|
      c.name = "POS"
      c.store = @store
    end
  end

  test "does not require an email for orders on the POS channel" do
    # require_email is skipped on the initial (new_record?) save regardless of
    # channel, so the exemption only proves itself on a later update — same
    # as a POS order created without email, then saved again (e.g. adding a
    # payment) without ever leaving the "draft" state.
    order = Spree::Order.create!(store: @store, channel: @channel, currency: "CLP", preferred_stock_location: @stock_location, status: "draft")
    order.customer_note = "second save, still no email"

    assert order.valid?
    assert_nil order.email
  end

  test "still requires an email for orders on other channels" do
    online_channel = Spree::Channel.find_or_create_by!(code: "online") { |c| c.name = "Online"; c.store = @store }
    # require_email is skipped on the initial (new_record?) save regardless of
    # state, so the requirement only bites on a later update — same as a real
    # checkout reaching the payment step.
    order = Spree::Order.create!(store: @store, channel: online_channel, currency: "CLP", email: "buyer@example.com", state: "cart")
    order.state = "payment"
    order.email = nil

    assert_not order.valid?
    assert_includes order.errors[:email], "can't be blank"
  end

  test "auto-assigns the preferred stock location's address as ship/bill address for anonymous POS orders" do
    order = Spree::Order.create!(
      store: @store, channel: @channel, currency: "CLP", preferred_stock_location: @stock_location, email: nil
    )

    assert order.ship_address.present?
    assert_equal "Providencia", order.ship_address.state.name
    assert_equal order.ship_address, order.bill_address
  end
end
