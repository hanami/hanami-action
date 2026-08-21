# frozen_string_literal: true

RSpec.describe Hanami::Action do
  describe "#session" do
    it "captures session from Rack env" do
      action   = SessionAction.new
      response = action.call("rack.session" => {"user_id" => "23"})

      expect(response.session).to eq(user_id: "23")
    end

    it "accepts session from TestHelper" do
      action   = SessionActionWithTestHelper.new
      response = action.call(session: {user_id: "23"})

      expect(response.session).to eq(user_id: "23")
    end

    it "returns empty hash when it is missing" do
      action   = SessionAction.new
      response = action.call({})

      expect(response.session).to eq({})
    end

    it "allows value access via symbols" do
      action   = SessionAction.new
      response = action.call("rack.session" => {"foo" => "bar"})

      expect(response.session[:foo]).to eq("bar")
    end
  end
end
