# frozen_string_literal: true

require "rack/test"
require "hanami/router"
require "hanami"

RSpec.describe "HTTP sessions" do
  include Rack::Test::Methods

  let(:router) do
    Hanami::Router.new do
      get    "/",       to: Dashboard::Index.new
      post   "/login",  to: Sessions::Create.new
      delete "/logout", to: Sessions::Destroy.new
      get    "/disabled", to: Sessions::Disabled.new
    end
  end

  let(:app) do
    r = router
    Rack::Builder.new do
      use Rack::Session::Cookie, secret: SecureRandom.hex(64)
      run r
    end.to_app
  end

  def response
    last_response
  end

  it "denies access if user isn't loggedin" do
    get "/"

    expect(response.status).to be(401)
  end

  it "grant access after login" do
    post "/login"
    follow_redirect!

    expect(response.status).to be(200)
    expect(response.body).to   eq("User ID from session: 23")
  end

  it "logs out" do
    post "/login"
    follow_redirect!

    expect(response.status).to be(200)

    delete "/logout"

    get "/"
    expect(response.status).to be(401)
  end

  context "when sessions not enabled" do
    it "raises Hanami::Action::MissingSessionError" do
      expected = Hanami::Action::MissingSessionError
      expect { get "/disabled" }.to raise_error(expected, /Hanami::Action::Response#session/)
    end
  end
end

RSpec.describe "HTTP Standalone Sessions" do
  include Rack::Test::Methods

  let(:app) do
    Rack::Builder.new do
      use Rack::Session::Cookie, secret: SecureRandom.hex(64)
      run StandaloneSession.new
    end.to_app
  end

  def response
    last_response
  end

  it "sets the session value" do
    get "/"
    expect(response.status).to be(200)
    expect(response.headers.fetch("Set-Cookie")).to match(/\Arack\.session/)
  end
end
