# frozen_string_literal: true

RSpec.describe "CSRF protection integration" do
  let(:raw_params) { [] }

  let(:action) do
    captured = raw_params

    Class.new(Hanami::Action) do
      include Hanami::Action::CSRFProtection

      define_method(:handle) do |req, _res|
        captured << req.params.raw
      end
    end.new
  end

  let(:app) do
    current_action = action

    routes = Hanami::Router.new do
      post "/painters/:id", to: current_action
    end

    Rack::MockRequest.new(routes)
  end

  let(:session_token) { "abc123" }

  def post_form(body)
    app.post(
      "/painters/23",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "rack.session" => {"_csrf_token" => session_token},
      input: body
    )
  end

  it "accepts a matching CSRF token in a routed form body" do
    response = post_form("_csrf_token=#{session_token}")

    expect(response.status).to eq 200
  end

  it "rejects a non-matching CSRF token in a routed form body" do
    expect { post_form("_csrf_token=non-matching") }.to raise_error Hanami::Action::InvalidCSRFTokenError
  end

  it "keeps form params under String keys in raw params, with route params taking precedence" do
    post_form("_csrf_token=#{session_token}&id=99&name=Klimt")

    expect(raw_params.first).to include("_csrf_token" => session_token, "name" => "Klimt", "id" => "23", id: "23")
  end
end
