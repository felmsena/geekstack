module SpreeTestHelpers
  # `default: true` is required here: Spree's `current_store` resolution
  # (Spree::Stores::FindDefault) ignores the request host entirely and just
  # returns `Store.where(default: true).first || Store.first`. Without this,
  # any pre-existing store in the database would win over the one this test
  # just created, and requests would 401 against the wrong store's API keys.
  def create_test_store(**attrs)
    unique = SecureRandom.hex(4)
    Spree::Store.create!({
      name: "Test Store",
      url: "test-#{unique}.example.com",
      code: "test-#{unique}",
      mail_from_address: "test@example.com",
      default_currency: "CLP",
      default_locale: "es-CL",
      supported_locales: "es,es-CL",
      default: true
    }.merge(attrs))
  end

  def create_test_order(store:, **attrs)
    Spree::Order.create!({
      store: store,
      email: "buyer@example.com",
      currency: "CLP",
      locale: "es-CL",
      total: 10_000
    }.merge(attrs))
  end

  # Creates an active, in-stock product so it can be added to a cart:
  # draft products and products without a StockItem both fail line item
  # validation ("cannot be added to cart" / "quantity ... not available").
  def create_test_product(store:, price: 9_990)
    shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default")
    stock_location = Spree::StockLocation.find_or_create_by!(name: "Test Stock") do |sl|
      sl.active = true
      sl.default = true
    end

    product = Spree::Product.create!(
      name: "Test Game", price: price, shipping_category: shipping_category, stores: [ store ], status: "active"
    )
    product.master.stock_items.find_or_create_by!(stock_location: stock_location) do |si|
      si.count_on_hand = 100
      si.backorderable = true
    end
    product
  end

  # Adds a line item and recalculates order totals through Spree's own
  # updater, since `line_items.create!` alone does not touch order.total.
  def add_line_item(order:, product:, quantity: 1)
    order.line_items.create!(variant: product.master, quantity: quantity, price: product.master.price)
    order.update_with_updater!
    order
  end

  def create_mercado_pago_payment_method(store:, **prefs)
    pm = Spree::PaymentMethod::MercadoPago.create!(name: "MercadoPago", stores: [ store ])
    prefs.each { |key, value| pm.public_send("preferred_#{key}=", value) }
    pm.save!
    pm
  end

  def create_publishable_api_key(store:)
    Spree::ApiKey.create!(name: "Test key", key_type: "publishable", store: store)
  end

  # Builds a StockLocation linked to a Zone via the "stock_location:<id>"
  # description convention, with a single commune (State) as a zone member.
  def create_test_stock_location_with_commune(commune_name: "Providencia")
    country = Spree::Country.find_or_create_by!(iso: "CL") do |c|
      c.name = "Chile"
      c.iso_name = "CHILE"
      c.iso3 = "CHL"
      c.numcode = 152
      c.states_required = true
    end
    state = Spree::State.find_or_create_by!(name: commune_name, country: country) do |s|
      s.abbr = commune_name[0, 4].upcase
    end

    location = Spree::StockLocation.create!(
      name: "Store #{SecureRandom.hex(2)}", active: true, country: country, state: state
    )
    zone = Spree::Zone.create!(name: "Zone #{location.id}", description: Geekstack::StoreZone.description_for(location))
    zone.zone_members.create!(zoneable: state)

    [ location, zone, state ]
  end
end
