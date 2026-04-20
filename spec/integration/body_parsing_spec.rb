# frozen_string_literal: true

require "stringio"

RSpec.describe "Body parsing", :app_integration do
  describe "JSON" do
    it "parses JSON for actions accepting :json format" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :json

        def handle(req, res)
          res.body = "City: #{req.params.dig(:user, :address, :city)}"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new('{"user":{"address":{"city":"Rome"}}}')
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(body).to eq(["City: Rome"])
    end
  end

  describe "Multipart forms" do
    it "parses multipart forms for actions accepting :html format" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :html

        def handle(req, res)
          res.body = "Title: #{req.params[:title]}"
        end
      end

      boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
      body = [
        "------WebKitFormBoundary7MA4YWxkTrZu0gW",
        'Content-Disposition: form-data; name="title"',
        "",
        "My Article",
        "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
      ].join("\r\n")

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
        "CONTENT_LENGTH" => body.bytesize.to_s,
        Rack::RACK_INPUT => StringIO.new(body)
      }

      status, _headers, response_body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(response_body).to eq(["Title: My Article"])
    end

    it "handles file uploads in multipart forms" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :html

        def handle(req, res)
          upload = req.params[:upload]
          # Rack 3 returns hash with :tempfile, Rack 2 returns file-like object
          if upload.is_a?(Hash) && upload[:tempfile]
            res.body = "File: #{upload[:tempfile].read}"
          elsif upload.respond_to?(:read)
            res.body = "File: #{upload.read}"
          else
            res.body = "No file"
          end
        end
      end

      boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
      file_content = "Hello from file"
      body = [
        "------WebKitFormBoundary7MA4YWxkTrZu0gW",
        'Content-Disposition: form-data; name="upload"; filename="test.txt"',
        "Content-Type: text/plain",
        "",
        file_content,
        "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
      ].join("\r\n")

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
        "CONTENT_LENGTH" => body.bytesize.to_s,
        Rack::RACK_INPUT => StringIO.new(body)
      }

      status, _headers, response_body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(response_body).to eq(["File: #{file_content}"])
    end
  end

  describe "Custom parsers" do
    it "uses custom parser registered with format" do
      custom_parser = lambda { |body, env|
        # Simple "strip tags"-style parsing
        {"data" => body.gsub(/<\/?[^>]+>/, "")}
      }

      action_class = Class.new(Hanami::Action) do
        config.formats.register(:xml, "application/xml", parser: custom_parser)
        config.formats.accept :xml

        def handle(req, res)
          res.body = "Data: #{req.params[:data]}"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/xml",
        Rack::RACK_INPUT => StringIO.new("<root>Test Content</root>")
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(body).to eq(["Data: Test Content"])
    end
  end

  describe "Multiple formats" do
    it "parses JSON when both :html and :json accepted" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :html, :json

        def handle(req, res)
          res.body = "Name: #{req.params[:name]}"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new('{"name":"Alice"}')
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(body).to eq(["Name: Alice"])
    end

    it "parses multipart when both :html and :json accepted" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :html, :json

        def handle(req, res)
          res.body = "Title: #{req.params[:title]}"
        end
      end

      boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
      body = [
        "------WebKitFormBoundary7MA4YWxkTrZu0gW",
        'Content-Disposition: form-data; name="title"',
        "",
        "My Article",
        "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
      ].join("\r\n")

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
        "CONTENT_LENGTH" => body.bytesize.to_s,
        Rack::RACK_INPUT => StringIO.new(body)
      }

      status, _headers, response_body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(response_body).to eq(["Title: My Article"])
    end
  end

  describe "Router parsing" do
    it "skips parsing when router.parsed_body already present" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :json

        def handle(req, res)
          res.body = "Value: #{req.params[:from_router]}"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new('{"from_action":"should_not_appear"}'),
        "router.parsed_body" => {"from_router" => "router_value"},
        "router.params" => {from_router: "router_value"}
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(200)
      expect(body).to eq(["Value: router_value"])
    end
  end

  describe "Error handling" do
    it "raises BodyParsingError for invalid JSON" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :json

        def handle(req, res)
          res.body = "Should not reach here"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new("{invalid json}")
      }

      expect {
        action_class.new.call(env)
      }.to raise_error(Hanami::Action::BodyParsingError)
    end

    it "raises BodyParsingError for invalid multipart data" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :html

        def handle(req, res)
          res.body = "Should not reach here"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "multipart/form-data; boundary=invalid",
        "CONTENT_LENGTH" => "13",
        Rack::RACK_INPUT => StringIO.new("invalid data!")
      }

      expect {
        action_class.new.call(env)
      }.to raise_error(Hanami::Action::BodyParsingError)
    end

    it "allows custom handling of body parsing errors" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :json
        config.handle_exception Hanami::Action::BodyParsingError => :handle_parse_error

        def handle(req, res)
          res.body = "Should not reach here"
        end

        def handle_parse_error(req, res, exception)
          res.status = 400
          res.body = "Custom error: #{exception.message}"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new("invalid json")
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(400)
      expect(body.first).to include("Custom error:")
    end
  end
end
