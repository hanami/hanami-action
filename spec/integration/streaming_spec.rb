# frozen_string_literal: true

RSpec.describe "Streaming a response body" do
  # Returns the Rack triplet that a web server would receive, checked by `Rack::Lint`.
  def rack_response(action, path = "/", **options)
    Rack::Lint
      .new(->(env) { action.new.call(env).to_a })
      .call(Rack::MockRequest.env_for(path, **options))
  end

  describe "an action that streams from a block" do
    let(:action) {
      Class.new(Hanami::Action) do
        def handle(*, response)
          response.stream { |out| 3.times { |i| out << "row #{i}\n" } }
        end
      end
    }

    it "sends a valid Rack response with no content-length" do
      status, headers, _body = rack_response(action)

      expect(status).to be 200
      expect(headers).not_to have_key("content-length")
    end

    it "sends the body in chunks" do
      _status, _headers, body = rack_response(action)

      chunks = []
      body.each { |chunk| chunks << chunk }

      expect(chunks).to eq ["row 0\n", "row 1\n", "row 2\n"]
    end
  end

  describe "an action that streams from an enumerable" do
    let(:action) {
      Class.new(Hanami::Action) do
        def handle(*, response)
          response.stream(["row 0\n", "row 1\n"])
        end
      end
    }

    it "sends the body in chunks" do
      _status, _headers, body = rack_response(action)

      chunks = []
      body.each { |chunk| chunks << chunk }

      expect(chunks).to eq ["row 0\n", "row 1\n"]
    end
  end

  describe "a stream that the response never sends" do
    it "is closed when a HEAD request empties the body" do
      stream = Hanami::Action::Stream.new { |out| out << "row" }
      action = Class.new(Hanami::Action) do
        define_method(:handle) { |*, response| response.body = stream }
      end

      rack_response(action, "/", method: "HEAD")

      expect(stream.closed?).to be true
    end

    it "is closed when the action halts" do
      stream = Hanami::Action::Stream.new { |out| out << "row" }
      action = Class.new(Hanami::Action) do
        define_method(:handle) do |*, response|
          response.body = stream
          halt 500
        end
      end

      rack_response(action)

      expect(stream.closed?).to be true
    end
  end

  describe "an action that streams lazily" do
    let(:built) { [] }

    let(:action) {
      rows = built

      Class.new(Hanami::Action) do
        define_method(:handle) do |*, response|
          response.stream do |out|
            3.times { |i|
              rows << i
              out << "row #{i}\n"
            }
          end
        end
      end
    }

    it "builds each chunk only when the server reads it" do
      _status, _headers, body = rack_response(action)
      expect(built).to be_empty

      # Reading one chunk is the point: the rest of the body is not built yet.
      body.each { break } # rubocop:disable Lint/UnreachableLoop
      expect(built).to eq [0]
    end
  end

  describe "an action that sends a file" do
    let(:file) { Pathname.new("spec/support/fixtures/test.txt") }

    let(:action) {
      Class.new(Hanami::Action) do
        def handle(*, response)
          response.unsafe_send_file("spec/support/fixtures/test.txt")
        end
      end
    }

    it "sends the file as a stream, with a content-length" do
      response = action.new.call(Rack::MockRequest.env_for("/"))

      expect(response.body).to be_a Hanami::Action::Stream
      expect(response.to_a[1]["content-length"]).to eq file.size.to_s
    end

    it "sends a valid Rack response with the contents of the file" do
      status, headers, body = rack_response(action)

      chunks = []
      body.each { |chunk| chunks << chunk }

      expect(status).to be 200
      expect(headers["content-length"]).to eq file.size.to_s
      expect(chunks.join).to eq file.read
    end

    it "sends the length of the file, not of the body it replaces" do
      replaced_body = "x" * (file.size + 1)

      action = Class.new(Hanami::Action) do
        define_method(:handle) do |*, response|
          response.body = replaced_body
          response.unsafe_send_file("spec/support/fixtures/test.txt")
        end
      end

      _status, headers, body = rack_response(action)

      expect(headers["content-length"]).to eq file.size.to_s

      chunks = []
      body.each { |chunk| chunks << chunk }

      expect(chunks.join).to eq file.read
    end
  end

  describe "a bare `Stream` constant" do
    it "resolves inside an action class" do
      # A `Class.new` block keeps the constant lookup of this file, so it cannot show this.
      # `class_eval` with a string gives the same lookup as a real class body, which is where
      # the affordance applies.
      action = Class.new(Hanami::Action)
      action.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def handle(*, response)
          response.body = Stream.new { |out| out << "row" }
        end
      RUBY

      response = action.new.call(Rack::MockRequest.env_for("/"))

      expect(response.body).to be_a Hanami::Action::Stream
    end
  end
end
