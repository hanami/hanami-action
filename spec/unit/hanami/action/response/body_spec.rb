# frozen_string_literal: true

RSpec.describe Hanami::Action::Response do
  subject(:response) { described_class.new(env:, request:, config: Hanami::Action.config.dup) }

  let(:request) { Hanami::Action::Request.new(env:, params: {}, session_enabled: false) }
  let(:env) { Rack::MockRequest.env_for("http://example.com/foo") }
  let(:stream) { Hanami::Action::Stream.new(%w[a b]) }

  describe "#body=" do
    describe "a String" do
      it "buffers the body and sets a content-length" do
        response.body = "hello"

        expect(response.to_a).to match [200, hash_including(rack_header("Content-Length") => "5"), ["hello"]]
      end
    end

    describe "an empty body" do
      it "accepts nil" do
        response.body = nil

        expect(response.to_a[2]).to eq []
      end

      it "accepts an empty array" do
        response.body = []

        expect(response.to_a[2]).to eq []
      end
    end

    describe "a Stream" do
      it "keeps the stream as the body" do
        response.body = stream

        expect(response.to_a[2]).to be stream
      end

      it "sets no content-length, so the server sends the response in chunks" do
        response.body = stream

        expect(response.to_a[1]).not_to have_key(rack_header("Content-Length"))
      end

      it "sets a content-length when the stream knows its length" do
        response.body = Hanami::Action::Stream.new(%w[a b], length: 2)

        expect(response.to_a[1]).to include(rack_header("Content-Length") => "2")
      end

      it "clears a content-length left by the body it replaces" do
        response.body = "hello"
        response.body = stream

        expect(response.to_a[1]).not_to have_key(rack_header("Content-Length"))
      end

      it "clears the content-length of a file it replaces" do
        response.unsafe_send_file("spec/support/fixtures/test.txt")
        response.body = stream

        expect(response.to_a[1]).not_to have_key(rack_header("Content-Length"))
      end

      it "does not read the stream" do
        read = false
        response.body = Hanami::Action::Stream.new(Enumerator.new { |y| read = true; y << "a" })

        expect(read).to be false
      end

      it "counts as a body, so a view does not replace it" do
        response.body = stream

        expect(response.renderable?).to be false
      end
    end

    describe "an unsupported object" do
      it "converts an object that is not a collection" do
        response.body = 42

        expect(response.to_a[2]).to eq ["42"]
      end

      it "raises for an Array, rather than sending its inspect output" do
        expect { response.body = ["a", "b"] }.to raise_error(
          Hanami::Action::InvalidBodyError, /Cannot use `Array'/
        )
      end

      it "raises for an Enumerator, rather than sending its inspect output" do
        expect { response.body = Enumerator.new { |y| y << "a" } }.to raise_error(
          Hanami::Action::InvalidBodyError, /Cannot use `Enumerator'/
        )
      end
    end

    describe "replacing the body" do
      it "closes the body it replaces" do
        response.body = stream
        response.body = "hello"

        expect(stream.closed?).to be true
      end

      it "does not close a body assigned over itself" do
        response.body = stream
        response.body = stream

        expect(stream.closed?).to be false
      end
    end
  end

  describe "#write" do
    it "appends to a buffered body" do
      response.body = "a"
      response.write("b")

      expect(response.to_a).to match [200, hash_including(rack_header("Content-Length") => "2"), %w[a b]]
    end

    it "raises when the body is a stream, rather than buffering it" do
      response.body = stream

      expect { response.write("a") }.to raise_error(
        Hanami::Action::InvalidBodyError, /Cannot write to a response that is streaming/
      )
      expect(stream.closed?).to be false
    end
  end

  describe "#stream" do
    it "makes a stream from a block and gives it to the body" do
      response.stream { |out| out << "a" << "b" }

      expect(response.body).to be_a Hanami::Action::Stream
      expect(response.body.each.to_a).to eq %w[a b]
    end

    it "makes a stream from an enumerable and gives it to the body" do
      response.stream(%w[a b])

      expect(response.body.each.to_a).to eq %w[a b]
    end

    it "returns the stream" do
      stream = response.stream(%w[a b])

      expect(stream).to be response.body
    end

    it "sets no content-length, so the server sends the response in chunks" do
      response.stream(%w[a b])

      expect(response.to_a[1]).not_to have_key(rack_header("Content-Length"))
    end

    it "passes on a given length" do
      response.stream(%w[a b], length: 2)

      expect(response.to_a[1]).to include(rack_header("Content-Length") => "2")
    end

    it "raises when given both an enumerable and a block" do
      expect { response.stream(%w[a]) { |out| out << "b" } }.to raise_error(ArgumentError)
    end
  end
end
