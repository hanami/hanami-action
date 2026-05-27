# frozen_string_literal: true

require_relative "../support/isolation_spec_helper"

RSpec.describe "Without validations" do
  it "doesn't load Dry::Validation" do
    expect(defined?(Dry::Validation)).to be(nil)
  end

  it "doesn't load Hanami::Action::Validatable" do
    expect(defined?(Hanami::Action::Validatable)).to be(nil)
  end

  it "doesn't have Hanami::Action.params" do
    expect do
      Class.new(Hanami::Action) do
        params do
          required(:id).filled
        end
      end
    end.to raise_error(
      NoMethodError,
      %(To use `.params`, please add the "dry-validation" gem to your Gemfile)
    )
  end

  it "doesn't have Hanami::Action.contract" do
    expect do
      Class.new(Hanami::Action) do
        contract do
          params do
            required(:id).filled
          end
        end
      end
    end.to raise_error(
      NoMethodError,
      %(To use `.contract`, please add the "dry-validation" gem to your Gemfile)
    )
  end

  it "has params that are always valid" do
    action = Class.new(Hanami::Action) do
      def handle(req, res)
        res.body = [req.params.respond_to?(:valid?), req.params.valid?]
      end
    end

    response = action.new.call({})
    expect(response.body).to eq(["[true, true]"])
  end
end

RSpec::Support::Runner.run
