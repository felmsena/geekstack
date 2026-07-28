# Spree's built-in region seeder (Carmen-backed) only models Chile at the
# region level (15 regions) — we never use that data, since our own zones
# work entirely at the comuna level (see db/seeds.rb, Geekstack::StoreZone).
#
# Worse: several Chilean regions share their exact name with their capital
# comuna (Antofagasta region / Antofagasta comuna; Valparaíso region /
# Valparaíso comuna). Spree::State has no concept of "level" — it's one flat
# table with `name` unique per country — so once a comuna with one of those
# names exists, this seeder's own attempt to create the same-named region
# fails with "Name has already been taken" on every later `db:seed` run
# (idempotent runs re-check `Country.where(states_required: true)`, which by
# then is true). Skipping Chile here avoids the collision entirely, for any
# region/comuna name pair, not just the one we've hit so far.
module Spree::Seeds::StatesDecorator
  def state_level(country, subregion)
    return if country.iso == "CL"

    super
  end

  def province_level(country, subregion)
    return if country.iso == "CL"

    super
  end
end

Spree::Seeds::States.prepend(Spree::Seeds::StatesDecorator)
