# frozen_string_literal: true

RSpec.describe Hanami::Action::Cache::Directives do
  describe "#directives" do
    context "non value directives" do
      it "accepts immutable symbol" do
        subject = described_class.new(:immutable)
        expect(subject.values.size).to eq(1)
      end

      it "accepts must_revalidate symbol" do
        subject = described_class.new(:must_revalidate)
        expect(subject.values.size).to eq(1)
      end

      it "accepts must_understand symbol" do
        subject = described_class.new(:must_understand)
        expect(subject.values.size).to eq(1)
      end

      it "accepts no_cache symbol" do
        subject = described_class.new(:no_cache)
        expect(subject.values.size).to eq(1)
      end

      it "accepts no_store symbol" do
        subject = described_class.new(:no_store)
        expect(subject.values.size).to eq(1)
      end

      it "accepts no_transform symbol" do
        subject = described_class.new(:no_transform)
        expect(subject.values.size).to eq(1)
      end

      it "accepts private symbol" do
        subject = described_class.new(:private)
        expect(subject.values.size).to eq(1)
      end

      it "accepts proxy_revalidate symbol" do
        subject = described_class.new(:proxy_revalidate)
        expect(subject.values.size).to eq(1)
      end

      it "accepts public symbol" do
        subject = described_class.new(:public)
        expect(subject.values.size).to eq(1)
      end

      it "raises ArgumentError for an unknown symbol" do
        expect { described_class.new(:weird) }
          .to raise_error(ArgumentError, "Unknown cache control directive: :weird")
      end

      context "multiple symbols" do
        it "creates one directive for each valid symbol" do
          subject = described_class.new(:private, :proxy_revalidate)
          expect(subject.values.size).to eq(2)
        end
      end

      context "private and public at the same time" do
        it "ignores public directive" do
          subject = described_class.new(:private, :public)
          expect(subject.values.size).to eq(1)
        end

        it "creates one private directive" do
          subject = described_class.new(:private, :public)
          expect(subject.values.first.name).to eq(:private)
        end
      end
    end

    describe "value directives" do
      it "accepts max_age symbol" do
        subject = described_class.new(max_age: 600)
        expect(subject.values.size).to eq(1)
      end

      it "accepts max_stale symbol" do
        subject = described_class.new(max_stale: 600)
        expect(subject.values.size).to eq(1)
      end

      it "accepts min_fresh symbol" do
        subject = described_class.new(min_fresh: 600)
        expect(subject.values.size).to eq(1)
      end

      it "accepts s_maxage symbol" do
        subject = described_class.new(s_maxage: 600)
        expect(subject.values.size).to eq(1)
      end

      it "accepts stale_if_error symbol" do
        subject = described_class.new(stale_if_error: 600)
        expect(subject.values.size).to eq(1)
      end

      it "accepts stale_while_revalidate symbol" do
        subject = described_class.new(stale_while_revalidate: 600)
        expect(subject.values.size).to eq(1)
      end

      it "raises ArgumentError for an unknown symbol" do
        expect { described_class.new(weird: 600) }
          .to raise_error(ArgumentError, "Unknown cache control directive: :weird")
      end

      context "multiple symbols" do
        it "creates one directive for each valid symbol" do
          subject = described_class.new(max_age: 600, max_stale: 600)
          expect(subject.values.size).to eq(2)
        end
      end
    end

    describe "value and non value directives" do
      it "creates one directive for each valid symbol" do
        subject = described_class.new(:public, max_age: 600, max_stale: 600)
        expect(subject.values.size).to eq(3)
      end
    end
  end
end
