# frozen_string_literal: true

require "rack/test"

module FullStack
  module Actions
    module Home
      class Index < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(*, res)
          res[:greeting] = "Hello"
        end
      end

      class Head < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(*, res)
          res.body = "foo"
        end
      end
    end

    module Books
      class Index < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(*)
        end
      end

      class Create < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        params do
          required(:title).filled(:str?)
        end

        def handle(req, res)
          req.params.valid?
          res.redirect_to "/books"
        end
      end

      class Update < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        params do
          required(:id).value(:integer)

          required(:book).schema do
            required(:title).filled(:str?)
            required(:author).schema do
              required(:name).filled(:str?)
              required(:favourite_colour)
            end
          end
        end

        def handle(req, res)
          valid = req.params.valid?

          res.status = 201
          res.body = JSON.generate(
            symbol_access: req.params[:book][:author] && req.params[:book][:author][:name],
            valid: valid,
            errors: req.params.errors.to_h
          )
        end
      end
    end

    module Settings
      class Index < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(*)
        end
      end

      class Create < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(*, res)
          res.flash[:message] = "Saved!"
          res.redirect_to "/settings"
        end
      end
    end

    module Poll
      class Start < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(*, res)
          res.redirect_to "/poll/1"
        end
      end

      class Step1 < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(req, res)
          if req.env["REQUEST_METHOD"] == "GET"
            res.flash[:notice] = "Start the poll"
          else
            res.flash[:notice] = "Step 1 completed"
            res.redirect_to "/poll/2"
          end
        end
      end

      class Step2 < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        def handle(req, res)
          if req.env["REQUEST_METHOD"] == "POST"
            res.flash[:notice] = "Poll completed"
            res.redirect_to "/"
          end
        end
      end
    end

    module Users
      class Show < Hanami::Action
        include Hanami::Action::Session
        include Inspector

        before :redirect_to_root
        after :set_body

        def handle(*, res)
          res.body = "call method shouldn't be called"
        end

        private

        def redirect_to_root(*, res)
          res.redirect_to "/"
        end

        def set_body
          res.body = "after callback shouldn't be called"
        end
      end
    end
  end

  class Application
    def initialize # rubocop:disable Metrics/AbcSize
      routes = Hanami::Router.new do
        get "/",     to: FullStack::Actions::Home::Index.new
        get "/head", to: FullStack::Actions::Home::Head.new
        get   "/books",     to: FullStack::Actions::Books::Index.new
        post  "/books",     to: FullStack::Actions::Books::Create.new
        patch "/books/:id", to: FullStack::Actions::Books::Update.new

        get  "/settings", to: FullStack::Actions::Settings::Index.new
        post "/settings", to: FullStack::Actions::Settings::Create.new

        get "/poll", to: FullStack::Actions::Poll::Start.new

        scope "poll" do
          get  "/1", to: FullStack::Actions::Poll::Step1.new
          post "/1", to: FullStack::Actions::Poll::Step1.new
          get  "/2", to: FullStack::Actions::Poll::Step2.new
          post "/2", to: FullStack::Actions::Poll::Step2.new
        end

        get "/users/1", to: FullStack::Actions::Users::Show.new
      end

      @renderer = Renderer.new
      @app      = Rack::Builder.new do
        use Rack::Session::Cookie, secret: SecureRandom.hex(64)
        run routes
      end.to_app
    end

    def call(env)
      @renderer.render(env, @app.call(env))
    end
  end
end

RSpec.describe "Full stack application" do
  include Rack::Test::Methods

  def app
    FullStack::Application.new
  end

  def parsed_body
    JSON.parse(last_response.body, symbolize_names: true)
  end

  it "passes action inside the Rack env" do
    get "/", {}, "HTTP_ACCEPT" => "text/html"

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Home::Index",
      exposures: {greeting: "Hello"},
      params: {},
      flash_now: {},
      flash_next: {}
    )
  end

  it "only allows entity headers if the request is HEAD" do
    head "/head", {}, "HTTP_ACCEPT" => "text/html"

    expect(last_response.body).to be_empty
    expect(last_response.headers.keys).to_not include("X-Renderable")
  end

  it "in case of redirect and invalid params, it passes errors in session and then deletes them" do
    post "/books", title: ""
    follow_redirect!

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Books::Index",
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {}
    )

    get "/books"
    expect(parsed_body).to eq(
      action: "FullStack::Actions::Books::Index",
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {}
    )
  end

  it "uses flash to pass informations" do
    get "/poll"
    follow_redirect!

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Poll::Step1",
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {notice: "Start the poll"}
    )

    post "/poll/1", {}
    follow_redirect!

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Poll::Step2",
      exposures: {},
      params: {},
      flash_now: {notice: "Step 1 completed"},
      flash_next: {}
    )
  end

  it "exposes flash queued for the next request" do
    get "/poll/1"

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Poll::Step1",
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {notice: "Start the poll"}
    )
  end

  it "completes the poll flow on the second step" do
    post "/poll/2", {}
    follow_redirect!

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Home::Index",
      exposures: {greeting: "Hello"},
      params: {},
      flash_now: {notice: "Poll completed"},
      flash_next: {}
    )
  end

  it "doesn't return stale informations when using redirect" do
    post "/settings", {}
    follow_redirect!

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Settings::Index",
      exposures: {},
      params: {},
      flash_now: {message: "Saved!"},
      flash_next: {}
    )

    get "/settings"

    expect(parsed_body).to eq(
      action: "FullStack::Actions::Settings::Index",
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {}
    )
  end

  it "doesn't return stale informations when not using redirect" do
    get "/poll/1"
    expect(parsed_body).to eq(
      action: "FullStack::Actions::Poll::Step1",
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {notice: "Start the poll"}
    )

    get "/settings"
    expect(parsed_body).to eq(
      action: "FullStack::Actions::Settings::Index",
      exposures: {},
      params: {},
      flash_now: {notice: "Start the poll"},
      flash_next: {}
    )
  end

  it "can access params with string symbols or methods" do
    patch "/books/1", book: {
      title: "Hanami in Action",
      author: {
        name: "Luca",
        favourite_colour: "purple"
      }
    }
    result = JSON.parse(last_response.body, symbolize_names: true)
    expect(result).to eq(
      symbol_access: "Luca",
      valid: true,
      errors: {}
    )
  end

  it "validates nested params" do
    patch "/books/1", book: {
      title: "Hanami in Action"
    }
    result = JSON.parse(last_response.body, symbolize_names: true)
    expect(result[:valid]).to  be(false)
    expect(result[:errors]).to eq(book: {author: ["is missing"]})
  end

  it "redirect in before action and call action method is not called" do
    get "users/1"

    expect(last_response.status).to be(302)
    expect(last_response.body).to   eq("Found") # This message is 302 status
  end
end
