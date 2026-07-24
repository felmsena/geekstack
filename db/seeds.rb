# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Spree::Core::Engine.load_seed if defined?(Spree::Core)

# --- Geekstack project seeds -------------------------------------------------
# Everything below reproduces, idempotently, the store/zone/shipping/payment
# configuration documented in CLAUDE.md so a fresh clone can run the app and
# the test/dev checkout flow without manual admin setup. Real credentials
# (MercadoPago access_token/public_key) are intentionally left blank here —
# set them via the admin or ENV, never commit real ones.

store = Spree::Store.find_or_initialize_by(code: "shop")
store.assign_attributes(
  name: "GeekStack",
  url: store.url.presence || "localhost:3000",
  mail_from_address: "no-reply@geekstack.cl",
  default_currency: "CLP",
  default_locale: "es-CL",
  supported_locales: "es,es-CL",
  default: true
)
store.save!

country = Spree::Country.find_by!(iso: "CL")
country.update!(states_required: true)
# Carmen (Spree's state-seeding data source) only models Chile at the region
# level (RM, VS, BI...), not comunas — so unlike other countries, Chilean
# comunas can't come from Spree::Seeds::States. They're created directly
# below, as plain Spree::State rows, exactly like `create_test_stock_location_with_commune`
# does in test/support/spree_test_helpers.rb.

shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")

national_zone = Spree::Zone.find_or_create_by!(name: "Chile") do |z|
  z.description = "Zona nacional Chile"
end
national_zone.zone_members.find_or_create_by!(zoneable: country)

tax_category = Spree::TaxCategory.find_or_create_by!(name: "IVA") { |tc| tc.is_default = true }
Spree::TaxRate.find_or_create_by!(name: "IVA 19%", tax_category: tax_category, zone: national_zone) do |tr|
  tr.amount = 0.19
  tr.included_in_price = true
  tr.calculator = Spree::Calculator::DefaultTax.new
end

# The two physical stores, each with its own StockLocation + a Zone that
# encodes which comunas that location ships to (Geekstack::StoreZone
# convention: zone.description == "stock_location:<id>").
STORE_LOCATIONS = {
  "Geekstack Providencia" => %w[
    Providencia Ñuñoa Las\ Condes Vitacura Lo\ Barnechea Santiago
    Recoleta Independencia Huechuraba San\ Miguel
  ],
  "Geekstack La Florida" => %w[
    La\ Florida Puente\ Alto La\ Pintana San\ Ramón El\ Bosque
    La\ Granja Macul Peñalolén San\ Joaquín La\ Cisterna
  ]
}.freeze

STORE_LOCATIONS.each do |location_name, comunas|
  location = Spree::StockLocation.find_or_create_by!(name: location_name) do |sl|
    sl.active = true
    sl.country = country
  end

  zone = Spree::Zone.find_or_create_by!(description: Geekstack::StoreZone.description_for(location)) do |z|
    z.name = "Despacho #{location_name}"
  end

  comunas.each do |comuna_name|
    # `abbr` is globally unique across all countries, so a truncated prefix
    # risks colliding with an unrelated state — use the full comuna name.
    state = Spree::State.find_or_create_by!(name: comuna_name, country: country) do |s|
      s.abbr = comuna_name.upcase
    end
    zone.zone_members.find_or_create_by!(zoneable: state)
  end

  Spree::ShippingMethod.find_or_create_by!(name: "Despacho #{location_name}") do |sm|
    sm.zones = [ zone ]
    sm.shipping_categories = [ shipping_category ]
    sm.display_on = "both"
    sm.calculator = Spree::Calculator::Shipping::FlatRate.new(preferred_amount: 0, preferred_currency: "CLP")
  end
end

Spree::ShippingMethod.find_or_create_by!(name: "Envío nacional") do |sm|
  sm.zones = [ national_zone ]
  sm.shipping_categories = [ shipping_category ]
  sm.display_on = "both"
  sm.calculator = Spree::Calculator::Shipping::FlatRate.new(preferred_amount: 3_990, preferred_currency: "CLP")
end

Spree::ShippingMethod.find_or_create_by!(name: "Retiro en tienda") do |sm|
  sm.zones = [ national_zone ]
  sm.shipping_categories = [ shipping_category ]
  sm.display_on = "both"
  sm.calculator = Spree::Calculator::Shipping::FlatRate.new(preferred_amount: 0, preferred_currency: "CLP")
end

Spree::PaymentMethod::Check.find_or_create_by!(name: "Transferencia bancaria") do |pm|
  pm.active = true
  pm.stores = [ store ]
end

mercado_pago = Spree::PaymentMethod::MercadoPago.find_or_create_by!(name: "MercadoPago") do |pm|
  pm.active = true
  pm.stores = [ store ]
end
mercado_pago.preferred_access_token ||= ""
mercado_pago.preferred_public_key   ||= ""
mercado_pago.save!
