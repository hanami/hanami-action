# frozen_string_literal: true

require "hanami/middleware/body_parser"

RSpec.describe "Route params precedence" do
  let(:action) do
    Class.new(Hanami::Action) do
      config.formats.accept :html, :json

      def handle(req, res)
        res.body = [req.params[:id], *req.params.raw.values_at("id", :id)].inspect
      end
    end.new
  end

  let(:routes) do
    current_action = action

    Hanami::Router.new do
      patch "/painters", to: current_action
      patch "/painters/:id", to: current_action
      patch "/files/*id", to: current_action
      scope "galleries/:id" do
        patch "/painters", to: current_action
      end
    end
  end

  let(:app) { Rack::MockRequest.new(routes) }

  def patch_json(path, body)
    app.request("PATCH", path, "CONTENT_TYPE" => "application/json", input: body.to_json)
  end

  def patch_multipart(path, fields)
    boundary = "----HanamiBoundary"
    body = fields.flat_map { |name, value|
      ["--#{boundary}", %(Content-Disposition: form-data; name="#{name}"), "", value]
    }.push("--#{boundary}--").join("\r\n")

    app.request(
      "PATCH",
      path,
      "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
      "CONTENT_LENGTH" => body.bytesize.to_s,
      input: body
    )
  end

  it "gives route params precedence over a JSON body" do
    expect(patch_json("/painters/23", {id: "42"}).body).to eq %w[23 23 23].inspect
  end

  it "gives route params precedence over a multipart body" do
    expect(patch_multipart("/painters/23", "id" => "42").body).to eq %w[23 23 23].inspect
  end

  it "gives route params precedence over a body giving the param as a Hash or an Array" do
    expect(patch_json("/painters/23", {id: {value: "42"}}).body).to eq %w[23 23 23].inspect
    expect(patch_json("/painters/23", {id: ["42"]}).body).to eq %w[23 23 23].inspect
  end

  it "gives route params precedence over a body when the query string repeats the route param" do
    expect(patch_json("/painters/23?id=23", {id: "42"}).body).to eq %w[23 23 23].inspect
  end

  it "gives globbed route params precedence over a body" do
    expect(patch_json("/files/23", {id: "42"}).body).to eq %w[23 23 23].inspect
  end

  it "gives route params from a scope precedence over a body" do
    expect(patch_json("/galleries/23/painters", {id: "42"}).body).to eq %w[23 23 23].inspect
  end

  it "gives a flat query string param precedence over the same param in a body" do
    expect(patch_json("/painters?id=23", {id: "42"}).body).to eq %w[23 23 23].inspect
  end

  it "gives a nested body param precedence over the same param in the query string" do
    expect(patch_json("/painters?id[value]=23", {id: {value: "42"}}).body)
      .to eq [{value: "42"}, {"value" => "42"}, {"value" => "42"}].inspect
  end

  context "with a body parsed by the router" do
    let(:app) do
      router = routes
      Rack::MockRequest.new(
        Rack::Builder.new do
          use Hanami::Middleware::BodyParser, :json
          run router
        end.to_app
      )
    end

    it "gives route params precedence over a JSON body" do
      expect(patch_json("/painters/23", {id: "42"}).body).to eq %w[23 23 23].inspect
    end
  end
end
