# frozen_string_literal: true

require "rack/test"

RSpec.describe Hanami::Action do
  describe "inheritance" do
    include Rack::Test::Methods

    let(:app) { Inheritance::Application.new }

    it "calls the exact chain of events" do
      get "/books/23"

      expect(last_response.body).to eq("[:base_action, :authenticated, :book, :found]")
    end

    it "supports conventional use of 'super' inside #handle" do
      delete "/books/23"

      expect(last_response.body).to eq("[:base_action, :authenticated, :book, :found, :destroyed]")
    end
  end
end
