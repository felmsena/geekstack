# Validates a Chilean RUT already normalized to "NNNNNNNN-D" (see
# Spree::UserDecorator#normalize_rut, which runs before this on save).
class ChileanRutValidator < ActiveModel::EachValidator
  FORMAT = /\A\d{7,8}-[0-9K]\z/

  def validate_each(record, attribute, value)
    return if value.blank?

    unless value.match?(FORMAT) && verifier_digit(value.split("-").first) == value.split("-").last
      record.errors.add(attribute, :invalid, message: "no es un RUT chileno válido")
    end
  end

  private

  # Módulo 11: each digit (right to left) is weighted 2..7 cyclically; the
  # verifier is 11 minus the remainder, mapped to "0"/"K" at the edges.
  def verifier_digit(digits)
    total = digits.reverse.chars.each_with_index.sum { |digit, index| digit.to_i * (2 + (index % 6)) }
    remainder = 11 - (total % 11)
    { 11 => "0", 10 => "K" }.fetch(remainder, remainder.to_s)
  end
end
