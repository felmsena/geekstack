# Cashier + the write actions a supervisor may need to correct a cashier's
# mistake: cancel an order, refund/void a payment, edit adjustments, and fix
# stock counts. Still no access to payment_methods/users/roles/API keys
# administration — that stays admin-only.
module Spree
  module PermissionSets
    class PosSupervisor < PosCashier
      def activate!
        super

        can [ :cancel, :approve, :resume ], Spree::Order

        can :void, Spree::Payment

        can [ :read, :admin, :index ], Spree::Refund
        can :create, Spree::Refund

        can [ :read, :admin, :index ], Spree::Adjustment

        can :manage, Spree::StockItem
      end
    end
  end
end
