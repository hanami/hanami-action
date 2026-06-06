# frozen_string_literal: true

# These tests exercise content-type negotiation through Action#call on the same action
# instance called multiple times in a row, with varied Accept headers. They pin down the
# behavior that any memoization around Mime.response_content_type_with_charset must
# preserve: distinct Accept strings produce distinct content types, repeated Accept
# strings produce the same content type, and switching between Accept-present and
# Accept-absent requests is handled correctly.
RSpec.describe Hanami::Action do
  describe "content type negotiation across multiple calls on the same instance" do
    context "permissive (no formats configured)" do
      let(:action_class) do
        Class.new(described_class) do
          def handle(*); end
        end
      end
      let(:action) { action_class.new }

      it "returns the right content type for each distinct Accept header" do
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "image/png").headers["Content-Type"])
          .to eq("image/png; charset=utf-8")
      end

      it "returns the same content type when the same Accept header is repeated" do
        first = action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"]
        second = action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"]
        third = action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"]

        expect(first).to eq("text/html; charset=utf-8")
        expect(second).to eq(first)
        expect(third).to eq(first)
      end

      it "does not let one Accept value pollute another's result when interleaved" do
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
      end

      it "handles weighted Accept headers correctly across repeated calls" do
        expect(action.call("HTTP_ACCEPT" => "text/html, application/xhtml+xml, image/jxr, */*").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json;q=0.5, text/html;q=0.9").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
      end

      it "handles mixed Accept-present and Accept-absent requests on the same instance" do
        expect(action.call({}).headers["Content-Type"])
          .to eq("application/octet-stream; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call({}).headers["Content-Type"])
          .to eq("application/octet-stream; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
      end
    end

    context "restrictive (specific formats configured)" do
      let(:action_class) do
        Class.new(described_class) do
          config.formats.accept :json, :html
          def handle(*); end
        end
      end
      let(:action) { action_class.new }

      it "returns the right content type for each Accept matching a configured format" do
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
      end

      it "falls back to the configured default format when Accept is */*" do
        expect(action.call("HTTP_ACCEPT" => "*/*").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
      end

      it "respects weighted Accept ordering across calls" do
        expect(action.call("HTTP_ACCEPT" => "application/json;q=0.5, text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "application/json, text/html;q=0.5").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
      end

      it "interleaves matching and wildcard Accepts without confusion" do
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "*/*").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "*/*").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
      end
    end

    context "with a non-default formats.default" do
      let(:action_class) do
        Class.new(described_class) do
          config.formats.accept :json, :html
          config.formats.default = :html
          def handle(*); end
        end
      end
      let(:action) { action_class.new }

      it "uses the configured default format when Accept is */*" do
        expect(action.call("HTTP_ACCEPT" => "*/*").headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
      end

      it "uses the configured default format when Accept is missing" do
        expect(action.call({}).headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
      end

      it "still negotiates when Accept matches an accepted non-default format" do
        expect(action.call("HTTP_ACCEPT" => "application/json").headers["Content-Type"])
          .to eq("application/json; charset=utf-8")
        expect(action.call({}).headers["Content-Type"])
          .to eq("text/html; charset=utf-8")
      end
    end

    context "when many distinct Accept headers are seen on the same instance" do
      let(:action_class) do
        Class.new(described_class) do
          def handle(*); end
        end
      end
      let(:action) { action_class.new }
      let(:cap) { Hanami::Action::ACCEPT_CONTENT_TYPE_CACHE_MAX_SIZE }

      it "still returns correct content types past the cache cap" do
        # Send (cap + 100) distinct Accept strings. The cache should soft-cap at `cap`,
        # but every call must still return a valid content type.
        (cap + 100).times do |i|
          response = action.call("HTTP_ACCEPT" => "application/x-test-#{i}")
          # Unknown Accept types fall back to "application/octet-stream" (the `:all` format).
          expect(response.headers["Content-Type"]).to eq("application/octet-stream; charset=utf-8")
        end
      end

      it "soft-caps the cache so it doesn't grow without bound" do
        (cap + 100).times do |i|
          action.call("HTTP_ACCEPT" => "application/x-test-#{i}")
        end

        cache = action.send(:accept_content_type_cache)
        expect(cache.size).to be <= cap
      end

      it "keeps serving cached entries that landed before the cap was reached" do
        # Warm one entry early.
        warmed = action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"]
        expect(warmed).to eq("text/html; charset=utf-8")

        # Fill the cache past the cap with junk.
        (cap + 100).times do |i|
          action.call("HTTP_ACCEPT" => "application/x-test-#{i}")
        end

        # The warmed entry should still be cached and still produce the same answer.
        cache = action.send(:accept_content_type_cache)
        expect(cache["text/html"]).to eq("text/html; charset=utf-8")
        expect(action.call("HTTP_ACCEPT" => "text/html").headers["Content-Type"]).to eq("text/html; charset=utf-8")
      end
    end
  end
end
