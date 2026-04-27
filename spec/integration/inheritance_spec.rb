# frozen_string_literal: true

require "rack/test"

RSpec.describe Hanami::Action do
  describe "inheritance" do
    include Rack::Test::Methods

    let(:base_action) do
      Class.new(Hanami::Action) do
        before :log_base_action

        private

        def log_base_action(*, res)
          res[:base_action] = true
        end
      end
    end

    let(:authenticated_action) do
      Class.new(base_action) do
        before :authenticate!

        private

        def authenticate!(*, res)
          res[:authenticated] = true
        end
      end
    end

    let(:restful_action) do
      Class.new(authenticated_action) do
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
    end

    let(:show_action) do
      Class.new(restful_action) do
        def handle(*, res)
          res[:found] = true
        end
      end
    end

    let(:destroy_action) do
      Class.new(show_action) do
        def handle(*, res)
          super
          res[:destroyed] = true
        end
      end
    end

    let(:app) do
      show    = show_action.new
      destroy = destroy_action.new

      Hanami::Router.new do
        get    "/books/:id", to: show
        delete "/books/:id", to: destroy
      end
    end

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
