# frozen_string_literal: true

require "stringio"

RSpec.describe "Params parsing" do
  describe "Error handling" do
    it "returns 400 Bad Request for a malformed query string" do
      action_class = Class.new(Hanami::Action) do
        def handle(req, res)
          res.body = "Should not reach here"
        end
      end

      env = {
        "REQUEST_METHOD" => "GET",
        "QUERY_STRING" => "a=1&a[b]=2",
        Rack::RACK_INPUT => StringIO.new
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(400)
      expect(body).to eq(["Bad Request"])
    end

    it "returns 400 Bad Request when a broader exception is also handled" do
      action_class = Class.new(Hanami::Action) do
        config.handle_exception StandardError => 500

        def handle(req, res)
          res.body = "Should not reach here"
        end
      end

      env = {
        "REQUEST_METHOD" => "GET",
        "QUERY_STRING" => "a=1&a[b]=2",
        Rack::RACK_INPUT => StringIO.new
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(400)
      expect(body).to eq(["Bad Request"])
    end

    it "allows custom handling of params parsing errors" do
      action_class = Class.new(Hanami::Action) do
        config.handle_exception Hanami::Action::ParamsParsingError => :handle_parse_error

        def handle(req, res)
          res.body = "Should not reach here"
        end

        def handle_parse_error(req, res, exception)
          res.status = 422
          res.body = "Custom error for #{req.request_method} with #{req.params.to_h}: #{exception.message}"
        end
      end

      env = {
        "REQUEST_METHOD" => "GET",
        "QUERY_STRING" => "a=1&a[b]=2",
        Rack::RACK_INPUT => StringIO.new
      }

      status, _headers, body = action_class.new.call(env)

      expect(status).to eq(422)
      expect(body.first).to start_with("Custom error for GET with {}: expected Hash")
    end
  end
end
