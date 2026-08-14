# frozen_string_literal: true

RSpec.describe Hanami::Action do
  describe ".after" do
    it "invokes the method(s) from the given symbol(s) after the action is run" do
      action = AfterMethodAction.new
      response = action.call({})

      expect(response[:egg]).to eq("gE!g")
      expect(response[:logger].join(" ")).to eq("Mrs. Jane Dixit")
      expect(response[:arguments]).to        eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end

    it "invokes the given block after the action is run" do
      action = AfterBlockAction.new
      response = action.call({})

      expect(response[:egg]).to       eq("Coque".reverse)
      expect(response[:arguments]).to eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end

    it "invokes the given callable object after the action is run" do
      action = AfterCallableAction.new
      response = action.call({})

      expect(response[:egg]).to   eq("Ei!".reverse)
      expect(response[:arguments]).to eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end

    it "invokes the given callable lambda after the action is run" do
      action = AfterLambdaAction.new
      response = action.call({})

      expect(response[:egg]).to       eq("CGA palette 1 enthusiast".reverse)
      expect(response[:arguments]).to eq(["Hanami::Action::Request", "Hanami::Action::Response"])
    end
  end
end
