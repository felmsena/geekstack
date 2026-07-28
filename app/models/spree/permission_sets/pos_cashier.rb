# Permission set for the presencial-sale (POS) "cashier" role.
#
# Deliberately built as an explicit allow-list (no `:manage`/wildcard grants)
# so everything not listed here is denied by CanCan's default. This is safer
# than reusing Spree::PermissionSets::OrderManagement, which also grants
# refunds/void/adjustments that a cashier must not have.
#
# Note on Spree::Order: read/write member actions on nested order resources
# (payments, fulfillments, items, store credits) are gated TWICE — once via
# `:show`/`:update` on the parent Spree::Order itself (see
# Spree::Api::V3::ResourceController#parent_ability_action), and again via the
# specific action on the child resource (e.g. `:capture` on Spree::Payment).
# `can :update, Spree::Order` here is that first, coarse gate; it does NOT by
# itself grant cancel/refund/void — those still require their own grant below,
# which cashier never gets.
#
# `:complete`/`:resend_confirmation` are kept distinct from `:cancel`/
# `:approve`/`:resume` by a decorator on Admin::OrdersController (see
# orders_controller_decorator.rb) — the stock controller collapses all of them
# into a single `:update` check, which would make "can complete but not
# cancel" impossible to express.
module Spree
  module PermissionSets
    class PosCashier < Base
      def activate!
        can [ :read, :admin, :index ], Spree::Product
        can [ :read, :admin ], Spree::Variant
        can [ :read, :admin, :index ], Spree::StockLocation
        can [ :read, :admin, :index ], Spree::StockItem
        can [ :read, :admin, :index ], Spree::PaymentMethod
        # Needed so the POS can look up the "pos" Spree::Channel's id
        # (GET /admin/channels?q[code_eq]=pos) to send as `channel_id` when
        # creating an order — without it, orders default to the "online"
        # channel and never get Spree::OrderDecorator's POS behavior
        # (anonymous checkout, auto-assigned pickup address).
        can [ :read, :admin, :index ], Spree::Channel

        can [ :read, :admin, :index ], Spree::Order
        can :create, Spree::Order
        can :update, Spree::Order
        can :complete, Spree::Order
        can :resend_confirmation, Spree::Order
        cannot [ :cancel, :approve, :resume ], Spree::Order

        can [ :read, :admin, :index, :create, :update, :destroy ], Spree::LineItem

        can [ :read, :admin, :index ], Spree::Payment
        can [ :create, :capture ], Spree::Payment

        can [ :read, :admin, :index ], Spree::Shipment
        can [ :create, :fulfill ], Spree::Shipment

        can [ :read, :admin, :index ], Spree::StoreCredit
        can :create, Spree::StoreCredit

        can [ :read, :admin, :index, :create, :update ], Spree.user_class
        can [ :read, :admin, :create, :update ], Spree::Address

        can [ :read, :admin ], :me
      end
    end
  end
end
