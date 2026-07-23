ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require_relative "support/spree_test_helpers"

WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SpreeTestHelpers

    # Requests in integration tests can switch I18n.locale based on the
    # current store's default_locale and leave it changed for whichever
    # test runs next in the same process. Reset it so tests don't depend
    # on run order.
    teardown do
      I18n.locale = I18n.default_locale
    end
  end
end
