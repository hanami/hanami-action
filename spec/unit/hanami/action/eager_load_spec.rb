# frozen_string_literal: true

RSpec.describe Hanami::Action do
  describe ".gem_loader" do
    it "can be eager loaded" do
      expect { described_class.gem_loader.eager_load(force: true) }.not_to raise_error
    end
  end
end
