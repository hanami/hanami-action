# frozen_string_literal: true

require "stringio"

RSpec.describe Hanami::Action::BodyParser do
  let(:config) { Class.new(Hanami::Action).config }

  describe ".parse" do
    it "reuses router-parsed body when present" do
      env = {"router.parsed_body" => {"existing" => "data"}}

      described_class.parse(env, config)

      expect(env["hanami.action.parsed_body"]).to eq("existing" => "data")
      expect(env["hanami.action.body_params"]).to eq(existing: "data")
      expect(env).not_to have_key("router.params")
    end

    it "skips if no rack.input" do
      env = {}

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "skips if no Content-Type header" do
      env = {Rack::RACK_INPUT => StringIO.new('{"key":"value"}')}

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "skips if Content-Type is empty" do
      env = {
        "CONTENT_TYPE" => "",
        Rack::RACK_INPUT => StringIO.new('{"key":"value"}')
      }

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "skips non-multipart content types when no formats are configured" do
      env = {
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new('{"key":"value"}')
      }

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "parses multipart/form-data automatically when no formats are configured" do
      boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
      body = [
        "------WebKitFormBoundary7MA4YWxkTrZu0gW",
        'Content-Disposition: form-data; name="title"',
        "",
        "My Title",
        "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
      ].join("\r\n")

      env = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
        "CONTENT_LENGTH" => body.bytesize.to_s,
        Rack::RACK_INPUT => StringIO.new(body)
      }

      described_class.parse(env, config)

      expect(env["hanami.action.parsed_body"]).to eq("title" => "My Title")
      expect(env["hanami.action.body_params"]).to eq(title: "My Title")
    end

    it "does not parse multipart/form-data automatically once any format is explicitly configured" do
      config.formats.accept :json

      boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
      body = [
        "------WebKitFormBoundary7MA4YWxkTrZu0gW",
        'Content-Disposition: form-data; name="title"',
        "",
        "My Title",
        "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
      ].join("\r\n")

      env = {
        "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
        "CONTENT_LENGTH" => body.bytesize.to_s,
        Rack::RACK_INPUT => StringIO.new(body)
      }

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "skips if content type not acceptable for configured formats" do
      config.formats.accept :html

      env = {
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new('{"key":"value"}')
      }

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "skips if no parser registered for content type" do
      config.formats.register(:custom, "application/custom")
      config.formats.accept :custom

      env = {
        "CONTENT_TYPE" => "application/custom",
        Rack::RACK_INPUT => StringIO.new("some data")
      }

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    it "skips if body is empty" do
      config.formats.accept :json

      env = {
        "CONTENT_TYPE" => "application/json",
        Rack::RACK_INPUT => StringIO.new("")
      }

      described_class.parse(env, config)

      expect(env).not_to have_key("hanami.action.parsed_body")
    end

    context "with JSON request" do
      it "parses when format accepted" do
        config.formats.accept :json

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => StringIO.new('{"name":"Alice","age":30}')
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("name" => "Alice", "age" => 30)
        expect(env["hanami.action.body_params"]).to eq(name: "Alice", age: 30)
      end

      it "leaves existing router.params untouched when parsing JSON" do
        config.formats.accept :json

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => StringIO.new('{"comment":{"body":"hello"}}'),
          "router.params" => {slug: "my-article"}
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("comment" => {"body" => "hello"})
        expect(env["hanami.action.body_params"]).to eq(comment: {body: "hello"})
        expect(env["router.params"]).to eq(slug: "my-article")
      end

      it "parses application/vnd.api+json" do
        # Register JSON:API format with vnd.api+json content type
        config.formats.register(:jsonapi, "application/vnd.api+json",
                                content_types: ["application/vnd.api+json"])
        config.formats.accept :jsonapi

        env = {
          "CONTENT_TYPE" => "application/vnd.api+json",
          Rack::RACK_INPUT => StringIO.new('{"data":{"type":"articles"}}')
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("data" => {"type" => "articles"})
        expect(env["hanami.action.body_params"]).to eq(data: {type: "articles"})
      end

      it "strips charset from Content-Type" do
        config.formats.accept :json

        env = {
          "CONTENT_TYPE" => "application/json; charset=utf-8",
          Rack::RACK_INPUT => StringIO.new('{"key":"value"}')
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("key" => "value")
      end

      it "handles nested objects" do
        config.formats.accept :json

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => StringIO.new('{"user":{"name":"Alice","tags":["ruby","hanami"]}}')
        }

        described_class.parse(env, config)

        expect(env["hanami.action.body_params"]).to eq(
          user: {
            name: "Alice",
            tags: ["ruby", "hanami"]
          }
        )
      end

      it "handles non-hash JSON (arrays)" do
        config.formats.accept :json

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => StringIO.new("[1,2,3]")
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq([1, 2, 3])
        expect(env["hanami.action.body_params"]).to eq(_: [1, 2, 3])
      end

      it "handles non-hash JSON with nested hashes (arrays of objects)" do
        config.formats.accept :json

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => StringIO.new('[{"name":"Alice","age":30},{"name":"Bob","age":25}]')
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq([{"name" => "Alice", "age" => 30}, {"name" => "Bob", "age" => 25}])
        expect(env["hanami.action.body_params"]).to eq(_: [{name: "Alice", age: 30}, {name: "Bob", age: 25}])
      end
    end

    context "with multipart form request" do
      it "parses when format accepted" do
        config.formats.accept :html

        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        body = [
          "------WebKitFormBoundary7MA4YWxkTrZu0gW",
          'Content-Disposition: form-data; name="title"',
          "",
          "My Title",
          "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
        ].join("\r\n")

        env = {
          "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
          "CONTENT_LENGTH" => body.bytesize.to_s,
          Rack::RACK_INPUT => StringIO.new(body)
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("title" => "My Title")
        expect(env["hanami.action.body_params"]).to eq(title: "My Title")
      end

      it "leaves existing router.params untouched when parsing multipart data" do
        config.formats.accept :html

        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        body = [
          "------WebKitFormBoundary7MA4YWxkTrZu0gW",
          'Content-Disposition: form-data; name="title"',
          "",
          "My Title",
          "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
        ].join("\r\n")

        env = {
          "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
          "CONTENT_LENGTH" => body.bytesize.to_s,
          Rack::RACK_INPUT => StringIO.new(body),
          "router.params" => {slug: "my-article"}
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("title" => "My Title")
        expect(env["hanami.action.body_params"]).to eq(title: "My Title")
        expect(env["router.params"]).to eq(slug: "my-article")
      end

      it "does not parse when only JSON accepted" do
        config.formats.accept :json

        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        body = [
          "------WebKitFormBoundary7MA4YWxkTrZu0gW",
          'Content-Disposition: form-data; name="title"',
          "",
          "My Title",
          "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
        ].join("\r\n")

        env = {
          "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
          "CONTENT_LENGTH" => body.bytesize.to_s,
          Rack::RACK_INPUT => StringIO.new(body)
        }

        described_class.parse(env, config)

        expect(env).not_to have_key("hanami.action.parsed_body")
      end
    end

    context "with custom parser" do
      it "uses custom parser when registered" do
        custom_parser = ->(body, env) { {"custom" => "parsed: #{body}"} }

        config.formats.register(:custom, "application/custom", parser: custom_parser)
        config.formats.accept :custom

        env = {
          "CONTENT_TYPE" => "application/custom",
          Rack::RACK_INPUT => StringIO.new("test data")
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("custom" => "parsed: test data")
        expect(env["hanami.action.body_params"]).to eq(custom: "parsed: test data")
      end

      it "uses directly registered parser" do
        custom_parser = ->(body, env) { {"direct" => body.upcase} }
        config.formats.body_parsers["application/direct"] = custom_parser
        config.formats.register(:direct, "application/direct")
        config.formats.accept :direct

        env = {
          "CONTENT_TYPE" => "application/direct",
          Rack::RACK_INPUT => StringIO.new("hello")
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("direct" => "HELLO")
      end
    end

    context "with multiple formats accepted" do
      it "parses JSON when JSON format accepted along with HTML" do
        config.formats.accept :html, :json

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => StringIO.new('{"key":"value"}')
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("key" => "value")
      end

      it "parses multipart when HTML format accepted along with JSON" do
        config.formats.accept :json, :html

        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        body = [
          "------WebKitFormBoundary7MA4YWxkTrZu0gW",
          'Content-Disposition: form-data; name="field"',
          "",
          "value",
          "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
        ].join("\r\n")

        env = {
          "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
          "CONTENT_LENGTH" => body.bytesize.to_s,
          Rack::RACK_INPUT => StringIO.new(body)
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("field" => "value")
      end
    end

    context "input rewinding" do
      it "rewinds input before and after reading" do
        config.formats.accept :json

        input = StringIO.new('{"key":"value"}')
        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => input
        }

        described_class.parse(env, config)

        expect(env["hanami.action.parsed_body"]).to eq("key" => "value")
        expect(input.pos).to eq(0) # Should be rewound
      end

      it "makes non-rewindable input rewindable" do
        config.formats.accept :json

        # Create a non-rewindable input
        input = StringIO.new('{"key":"value"}')
        input.singleton_class.undef_method(:rewind)

        env = {
          "CONTENT_TYPE" => "application/json",
          Rack::RACK_INPUT => input
        }

        expect {
          described_class.parse(env, config)
        }.not_to raise_error

        expect(env["hanami.action.parsed_body"]).to eq("key" => "value")
      end
    end
  end
end
