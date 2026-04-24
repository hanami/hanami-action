# frozen_string_literal: true

require "rack/test"

module InheritanceSpec
  class Action < Hanami::Action
    before :log_base_action

    private

    def log_base_action(*, res)
      res[:base_action] = true
    end
  end

  class AuthenticatedAction < Action
    before :authenticate!

    private

    def authenticate!(*, res)
      res[:authenticated] = true
    end
  end

  module Controllers
    module Books
      class RestfulAction < AuthenticatedAction
        before :find_book
        after :render

        private

        def find_book(req, res)
          res[:book] = "book #{req.params[:id]}"
        end

        def render(*, res)
          res.body = res.exposures.keys
        end
      end

      class Show < RestfulAction
        def handle(*, res)
          res[:found] = true
        end
      end

      class Destroy < Show
        def handle(*, res)
          super
          res[:destroyed] = true
        end
      end
    end
  end

  class Application
    def initialize
      @routes = Hanami::Router.new do
        get "/books/:id", to: InheritanceSpec::Controllers::Books::Show.new
        delete "/books/:id", to: InheritanceSpec::Controllers::Books::Destroy.new
      end
    end

    def call(env)
      @routes.call(env)
    end
  end
end

RSpec.describe Hanami::Action do
  describe "inheritance" do
    include Rack::Test::Methods

    let(:app) { InheritanceSpec::Application.new }

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
