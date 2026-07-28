# Scoped to the Admin API only, for the presencial-sale (POS) client — the
# Store API (customer storefront) doesn't need cross-origin access from a
# browser today, so it's intentionally left out.
#
# `credentials: true` is required: the Admin API's refresh token is an
# httpOnly cookie (see spree_api's Admin::AuthCookies), not a body field, so
# the POS must send it via `credentials: 'include'` — which the browser
# refuses unless the response echoes back a specific origin (never `*`) with
# this header.
#
# POS_CORS_ORIGINS is a comma-separated list, e.g.
# "http://localhost:3001,https://pos.geekstack.cl". Empty/unset means no
# origin is allowed yet — set this once the POS's dev/prod origins are known.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("POS_CORS_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)

    resource "/api/v3/admin/*",
      headers: :any,
      methods: %i[get post patch put delete options head],
      expose: %w[Idempotent-Replayed],
      credentials: true
  end
end
