ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActionDispatch::TestProcess::FixtureFile

    # Foto mínima para criar cartões-resposta nos testes
    def sheet_image
      fixture_file_upload("cartao.jpg", "image/jpeg")
    end
  end
end
