# frozen_string_literal: true

RSpec.describe Hanami::Action do
  describe ".before" do
    it "invokes the method(s) from the given symbol(s) before the action is run" do
      action = BeforeMethodAction.new
      response = action.call({})

      expect(response[:article]).to          eq("Bonjour!".reverse)
      expect(response[:logger].join(" ")).to eq("Mr. John Doe")
      expect(response[:arguments]).to        eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end

    it "invokes the given block before the action is run" do
      action = BeforeBlockAction.new
      response = action.call({})

      expect(response[:article]).to   eq("Good morning!".reverse)
      expect(response[:arguments]).to eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end

    it "invokes the given callable object before the action is run" do
      action = BeforeCallableAction.new
      response = action.call({})

      expect(response[:article]).to   eq("Guten Tag!".reverse)
      expect(response[:arguments]).to eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end
  end
end
