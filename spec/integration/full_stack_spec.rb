# frozen_string_literal: true

require "json"
require "rack/test"

RSpec.describe "Full stack application" do
  include Rack::Test::Methods

  let(:base_action) do
    Class.new(Hanami::Action) do
      include Hanami::Action::Session

      after do |req, res|
        res[:params] = req.params.to_h
        req.env["hanami.response"] = res
      end
    end
  end

  let(:response_serializer) do
    Class.new do
      def render(env, response)
        action   = env.delete(Hanami::Action::ACTION_INSTANCE)
        response = env.delete("hanami.response") || response

        handle_hanami_response(env, action, response) ||
          handle_rack_response(env, action, response)

        response
      end

      private

      def handle_hanami_response(env, action, response)
        return unless response.respond_to?(:status)

        if response.status == 200 && !head_request?(env)
          response.body = JSON.generate(
            action_object_id: action.object_id,
            exposures: response.exposures.reject { |key, _| key == :params || key == :format },
            params: response[:params].to_h,
            flash_now: response.flash.now,
            flash_next: response.flash.next
          )
        end

        true
      end

      def handle_rack_response(env, action, response)
        if response[0] == 200 && !head_request?(env)
          response[2] = JSON.generate(
            action_object_id: action.object_id,
            params: env["router.params"].to_h,
            flash_now: env["rack.session"].fetch(Hanami::Action::Flash::KEY, nil),
            flash_next: nil
          )
        end
      end

      def head_request?(env)
        env[Hanami::Action::REQUEST_METHOD] == Hanami::Action::HEAD
      end
    end.new
  end

  let(:home_index) do
    Class.new(base_action) do
      def handle(*, res)
        res[:greeting] = "Hello"
      end
    end.new
  end

  let(:home_head) do
    Class.new(base_action) do
      def handle(*, res)
        res.body = "foo"
      end
    end.new
  end

  let(:books_index) do
    Class.new(base_action) do
      def handle(*)
      end
    end.new
  end

  let(:books_create) do
    Class.new(base_action) do
      params do
        required(:title).filled(:str?)
      end

      def handle(req, res)
        req.params.valid?
        res.redirect_to "/books"
      end
    end.new
  end

  let(:books_update) do
    Class.new(base_action) do
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
    end.new
  end

  let(:settings_index) do
    Class.new(base_action) do
      def handle(*)
      end
    end.new
  end

  let(:settings_create) do
    Class.new(base_action) do
      def handle(*, res)
        res.flash[:message] = "Saved!"
        res.redirect_to "/settings"
      end
    end.new
  end

  let(:poll_start) do
    Class.new(base_action) do
      def handle(*, res)
        res.redirect_to "/poll/1"
      end
    end.new
  end

  let(:poll_step1) do
    Class.new(base_action) do
      def handle(req, res)
        if req.env["REQUEST_METHOD"] == "GET"
          res.flash[:notice] = "Start the poll"
        else
          res.flash[:notice] = "Step 1 completed"
          res.redirect_to "/poll/2"
        end
      end
    end.new
  end

  let(:poll_step2) do
    Class.new(base_action) do
      def handle(req, res)
        if req.env["REQUEST_METHOD"] == "POST"
          res.flash[:notice] = "Poll completed"
          res.redirect_to "/"
        end
      end
    end.new
  end

  let(:users_show) do
    Class.new(base_action) do
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
    end.new
  end

  let(:app) do
    # Capture the memoized actions as locals because the router block is
    # instance_eval'd, which puts the `let` methods out of scope inside it.
    home_index_action      = home_index
    home_head_action       = home_head
    books_index_action     = books_index
    books_create_action    = books_create
    books_update_action    = books_update
    settings_index_action  = settings_index
    settings_create_action = settings_create
    poll_start_action      = poll_start
    poll_step1_action      = poll_step1
    poll_step2_action      = poll_step2
    users_show_action      = users_show
    serializer             = response_serializer

    routes = Hanami::Router.new do
      get "/",     to: home_index_action
      get "/head", to: home_head_action
      get   "/books",     to: books_index_action
      post  "/books",     to: books_create_action
      patch "/books/:id", to: books_update_action

      get  "/settings", to: settings_index_action
      post "/settings", to: settings_create_action

      get "/poll", to: poll_start_action

      scope "poll" do
        get  "/1", to: poll_step1_action
        post "/1", to: poll_step1_action
        get  "/2", to: poll_step2_action
        post "/2", to: poll_step2_action
      end

      get "/users/1", to: users_show_action
    end

    inner = Rack::Builder.new do
      use Rack::Session::Cookie, secret: SecureRandom.hex(64)
      run routes
    end.to_app

    ->(env) { serializer.render(env, inner.call(env)) }
  end

  def parsed_body
    JSON.parse(last_response.body, symbolize_names: true)
  end

  it "passes action inside the Rack env" do
    get "/", {}, "HTTP_ACCEPT" => "text/html"

    expect(parsed_body).to eq(
      action_object_id: home_index.object_id,
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
      action_object_id: books_index.object_id,
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {}
    )

    get "/books"
    expect(parsed_body).to eq(
      action_object_id: books_index.object_id,
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
      action_object_id: poll_step1.object_id,
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {notice: "Start the poll"}
    )

    post "/poll/1", {}
    follow_redirect!

    expect(parsed_body).to eq(
      action_object_id: poll_step2.object_id,
      exposures: {},
      params: {},
      flash_now: {notice: "Step 1 completed"},
      flash_next: {}
    )
  end

  it "exposes flash queued for the next request" do
    get "/poll/1"

    expect(parsed_body).to eq(
      action_object_id: poll_step1.object_id,
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
      action_object_id: home_index.object_id,
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
      action_object_id: settings_index.object_id,
      exposures: {},
      params: {},
      flash_now: {message: "Saved!"},
      flash_next: {}
    )

    get "/settings"

    expect(parsed_body).to eq(
      action_object_id: settings_index.object_id,
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {}
    )
  end

  it "doesn't return stale informations when not using redirect" do
    get "/poll/1"
    expect(parsed_body).to eq(
      action_object_id: poll_step1.object_id,
      exposures: {},
      params: {},
      flash_now: {},
      flash_next: {notice: "Start the poll"}
    )

    get "/settings"
    expect(parsed_body).to eq(
      action_object_id: settings_index.object_id,
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
    expect(last_response.body).to   eq("Found")
  end
end
