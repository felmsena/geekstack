module Geekstack
  # The Spree::Channel code that identifies presencial (POS) sales, so the
  # anonymous-order exemption (Spree::OrderDecorator#require_email) and the
  # seed that creates the channel always agree on the same string.
  class PosChannel
    CODE = "pos".freeze
  end
end
