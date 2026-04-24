# frozen_string_literal: true

RSpec.describe "Body parser route params integration" do
  let(:action) do
    Class.new(Hanami::Action) do
      config.formats.accept :html, :json

      params do
        required(:id).filled(:str?)

        required(:painter).schema do
          required(:first_name).filled(:str?)
          required(:last_name).filled(:str?)
        end
      end

      def handle(req, res)
        res.body = req.params.to_h.inspect
      end
    end.new
  end

  let(:app) do
    current_action = action

    routes = Hanami::Router.new do
      patch "/painters/:id", to: current_action
    end

    Rack::MockRequest.new(
      Rack::Builder.new do
        use Rack::Lint
        run routes
      end.to_app
    )
  end

  it "preserves route params when parsing JSON" do
    response = app.request(
      "PATCH",
      "/painters/23",
      "CONTENT_TYPE" => "application/json",
      input: {painter: {first_name: "Gustav", last_name: "Klimt"}}.to_json
    )

    expect(response.status).to eq(200)
    expect(response.body).to eq({id: "23", painter: {first_name: "Gustav", last_name: "Klimt"}}.inspect)
  end

  it "preserves route params when parsing multipart form data" do
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    body = [
      "--#{boundary}",
      'Content-Disposition: form-data; name="painter[first_name]"',
      "",
      "Gustav",
      "--#{boundary}",
      'Content-Disposition: form-data; name="painter[last_name]"',
      "",
      "Klimt",
      "--#{boundary}--"
    ].join("\r\n")

    response = app.request(
      "PATCH",
      "/painters/23",
      "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
      "CONTENT_LENGTH" => body.bytesize.to_s,
      input: body
    )

    expect(response.status).to eq(200)
    expect(response.body).to eq({id: "23", painter: {first_name: "Gustav", last_name: "Klimt"}}.inspect)
  end
end
