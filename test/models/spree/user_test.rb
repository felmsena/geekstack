require "test_helper"

class Spree::UserTest < ActiveSupport::TestCase
  def build_user(rut: nil)
    Spree::User.new(
      email: "user_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      rut: rut
    )
  end

  test "requires a rut" do
    user = build_user
    assert_not user.valid?
    assert_includes user.errors[:rut], "can't be blank"
  end

  test "normalizes dots and missing dashes before validating" do
    user = build_user(rut: "12.345.678-5")
    assert user.valid?
    assert_equal "12345678-5", user.rut

    user = build_user(rut: "123456785")
    assert user.valid?
    assert_equal "12345678-5", user.rut
  end

  test "uppercases a K verifier digit" do
    user = build_user(rut: "12.345.670-k")
    assert user.valid?
    assert_equal "12345670-K", user.rut
  end

  test "rejects a rut with an invalid check digit" do
    user = build_user(rut: "11111111-2")
    assert_not user.valid?
    assert_includes user.errors[:rut], "no es un RUT chileno válido"
  end

  test "rejects a malformed rut" do
    user = build_user(rut: "not-a-rut")
    assert_not user.valid?
    assert_includes user.errors[:rut], "no es un RUT chileno válido"
  end

  test "enforces uniqueness regardless of formatting" do
    create_test_store
    build_user(rut: "12345678-5").save!
    duplicate = build_user(rut: "12.345.678-5")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:rut], "has already been taken"
  end
end
