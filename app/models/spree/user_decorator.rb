module Spree::UserDecorator
  def self.prepended(base)
    base.before_validation :normalize_rut
    base.validates :rut, presence: true, uniqueness: { case_sensitive: false, allow_nil: true }, chilean_rut: true
  end

  private

  # Accepts "12.345.678-9", "12345678-9" or "123456789" and normalizes all of
  # them to the canonical "12345678-9" form the validator/index expect.
  def normalize_rut
    return if rut.blank?

    cleaned = rut.to_s.gsub(/[^0-9Kk]/, "").upcase
    self.rut = "#{cleaned[0..-2]}-#{cleaned[-1]}" if cleaned.length > 1
  end
end

Spree::User.prepend(Spree::UserDecorator)
