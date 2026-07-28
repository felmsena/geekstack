# The stock controller maps :complete/:cancel/:approve/:resume/
# :resend_confirmation all onto a single :update CanCan check, so any role
# with :update on Spree::Order gets all five together. That makes it
# impossible to express "can complete an order but not cancel it" (the POS
# cashier role), so here each member action is authorized under its own name
# instead of being collapsed.
module Spree::Api::V3::Admin::OrdersControllerDecorator
  private

  def authorize_resource!(resource = @resource, action = action_name.to_sym)
    authorize!(action, resource)
  end
end

Spree::Api::V3::Admin::OrdersController.prepend(Spree::Api::V3::Admin::OrdersControllerDecorator)
