# frozen_string_literal: true

RSpec.describe Hanami::Action::Stream do
  describe "#initialize" do
    it "accepts an enumerable of chunks" do
      expect { described_class.new(["a"]) }.not_to raise_error
    end

    it "accepts a block" do
      expect { described_class.new { |out| out << "a" } }.not_to raise_error
    end

    it "raises if given both an enumerable and a block" do
      expect { described_class.new(["a"]) { |out| out << "b" } }.to raise_error(
        ArgumentError, /either an enumerable of chunks or a block/
      )
    end

    it "raises if given neither an enumerable nor a block" do
      expect { described_class.new }.to raise_error(
        ArgumentError, /either an enumerable of chunks or a block/
      )
    end
  end

  describe "#each" do
    it "yields the chunks of an enumerable" do
      chunks = []
      described_class.new(%w[a b c]).each { |chunk| chunks << chunk }

      expect(chunks).to eq %w[a b c]
    end

    it "yields the chunks written by a block" do
      chunks = []
      described_class.new { |out| out << "a" << "b" }.each { |chunk| chunks << chunk }

      expect(chunks).to eq %w[a b]
    end

    it "yields lazily, chunk by chunk" do
      yielded = []
      source = Enumerator.new { |y|
        yielded << :first
        y << "a"
        yielded << :second
        y << "b"
      }

      described_class.new(source).each.first

      expect(yielded).to eq [:first]
    end

    it "returns an enumerator when given no block" do
      expect(described_class.new(%w[a b]).each.to_a).to eq %w[a b]
    end

    it "raises if a chunk is not a String" do
      expect { described_class.new([1]).each { |chunk| chunk } }.to raise_error(
        Hanami::Action::StreamError, /Received `Integer'/
      )
    end

    it "raises if the stream is closed" do
      stream = described_class.new(%w[a])
      stream.close

      expect { stream.each { |chunk| chunk } }.to raise_error(
        Hanami::Action::StreamError, /This stream is closed/
      )
    end
  end

  describe "#close" do
    it "closes the enumerable, if it can be closed" do
      source = Class.new {
        attr_reader :closed

        def each(*); end

        def close = @closed = true
      }.new

      expect { described_class.new(source).close }
        .to change { source.closed }.to true
    end

    it "closes only once" do
      source = double(:source, each: nil)
      allow(source).to receive(:close)

      stream = described_class.new(source)
      2.times { stream.close }

      expect(source).to have_received(:close).once
    end

    it "does nothing for an enumerable that cannot be closed" do
      expect { described_class.new(%w[a]).close }.not_to raise_error
    end
  end

  describe "#closed?" do
    it "returns false until the stream is closed" do
      stream = described_class.new(%w[a])

      expect { stream.close }
        .to change { stream.closed? }
        .from(false).to true
    end
  end

  describe "#length" do
    it "is nil by default" do
      expect(described_class.new(%w[a]).length).to be nil
    end

    it "returns the given length" do
      expect(described_class.new(%w[a], length: 1).length).to eq 1
    end
  end

  describe "#empty?" do
    it "returns false" do
      expect(described_class.new(%w[a]).empty?).to be false
    end
  end

  it "does not respond to #to_ary, which would let a server buffer it" do
    expect(described_class.new(%w[a])).not_to respond_to(:to_ary)
  end
end
