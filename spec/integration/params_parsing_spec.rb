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

    it "returns 415 Unsupported Media Type for a malformed form body when the action does not accept forms" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :json

        def handle(req, res)
          res.body = "Should not reach here"
        end
      end

      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/x-www-form-urlencoded",
        "CONTENT_LENGTH" => "10",
        Rack::RACK_INPUT => StringIO.new("a=1&a[b]=2")
      }

      status, _headers, _body = action_class.new.call(env)

      expect(status).to eq(415)
    end

    it "returns 415 Unsupported Media Type for a malformed multipart body when the action does not accept multipart" do
      action_class = Class.new(Hanami::Action) do
        config.formats.accept :json

        def handle(req, res)
          res.body = "Should not reach here"
        end
      end

      body = "--XYZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nhello"
      env = {
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "multipart/form-data; boundary=XYZ",
        "CONTENT_LENGTH" => body.bytesize.to_s,
        Rack::RACK_INPUT => StringIO.new(body)
      }

      status, _headers, _body = action_class.new.call(env)

      expect(status).to eq(415)
    end

    describe "an unexpected error while building params" do
      let(:action_class) {
        Class.new(Hanami::Action) do
          contract do
            params do
              required(:a).filled(:string)
            end

            rule(:a) { raise "boom" }
          end

          def handle(req, res)
            res.body = "Should not reach here"
          end
        end
      }

      let(:env) {
        {
          "REQUEST_METHOD" => "GET",
          "QUERY_STRING" => "a=1",
          Rack::RACK_INPUT => StringIO.new,
          "rack.errors" => rack_errors
        }
      }

      let(:rack_errors) { StringIO.new }

      it "raises the original error, and references it in rack.errors" do
        expect { action_class.new.call(env) }.to raise_error(RuntimeError, "boom")

        expect(env["rack.exception"]).to be_a(RuntimeError)
        expect(rack_errors.string).to start_with("RuntimeError: boom")
      end

      it "can be handled with config.handle_exception" do
        action_class.config.handle_exception RuntimeError => :handle_boom
        action_class.define_method(:handle_boom) do |req, res, exception|
          res.status = 422
          res.body = "Handled #{exception.message} for #{req.request_method} with #{req.params.to_h}"
        end

        status, _headers, body = action_class.new.call(env)

        expect(status).to eq(422)
        expect(body).to eq(["Handled boom for GET with {}"])
      end
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
