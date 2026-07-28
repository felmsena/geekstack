require "test_helper"

class Spree::PosPermissionSetsTest < ActiveSupport::TestCase
  setup do
    @store = create_test_store
    @order = create_test_order(store: @store)
    @payment = @order.payments.build(amount: 1, payment_method: create_mercado_pago_payment_method(store: @store))
    @cashier_role = Spree::Role.find_or_create_by!(name: "cashier")
    @supervisor_role = Spree::Role.find_or_create_by!(name: "supervisor")
  end

  def ability_for(role)
    user = Spree::AdminUser.create!(email: "#{role.name}_#{SecureRandom.hex(4)}@example.com", password: "password123")
    Spree::RoleUser.create!(user: user, role: role, store: @store)
    Spree::Ability.new(user, store: @store)
  end

  test "cashier can create and capture payments but not void them" do
    ability = ability_for(@cashier_role)

    assert ability.can?(:create, Spree::Payment)
    assert ability.can?(:capture, Spree::Payment)
    assert_not ability.can?(:void, Spree::Payment)
  end

  test "cashier can read channels (needed to look up the pos channel_id for order creation)" do
    ability = ability_for(@cashier_role)

    assert ability.can?(:read, Spree::Channel)
    assert_not ability.can?(:update, Spree::Channel)
  end

  test "cashier can complete an order but not cancel, approve, or resume it" do
    ability = ability_for(@cashier_role)

    assert ability.can?(:create, Spree::Order)
    assert ability.can?(:update, Spree::Order)
    assert ability.can?(:complete, Spree::Order)
    assert ability.can?(:resend_confirmation, Spree::Order)
    assert_not ability.can?(:cancel, Spree::Order)
    assert_not ability.can?(:approve, Spree::Order)
    assert_not ability.can?(:resume, Spree::Order)
  end

  test "cashier cannot create refunds, edit adjustments, or write stock/payment methods" do
    ability = ability_for(@cashier_role)

    assert_not ability.can?(:create, Spree::Refund)
    assert_not ability.can?(:create, Spree::Adjustment)
    assert_not ability.can?(:update, Spree::StockItem)
    assert_not ability.can?(:update, Spree::PaymentMethod)
    assert_not ability.can?(:destroy, Spree.user_class)
  end

  test "supervisor has everything cashier has, plus cancel/refund/adjustments/stock" do
    ability = ability_for(@supervisor_role)

    assert ability.can?(:complete, Spree::Order)
    assert ability.can?(:cancel, Spree::Order)
    assert ability.can?(:void, Spree::Payment)
    assert ability.can?(:create, Spree::Refund)
    assert ability.can?(:update, Spree::StockItem)
  end
end
