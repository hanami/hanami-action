# frozen_string_literal: true

RSpec.describe "Exception notifiers integration" do
  let(:env) { {} }

  it "reference error in rack.exception" do
    expect { RackExceptionAction.new.call(env) }.to raise_error(RackExceptionAction::TestException)

    expect(env["rack.exception"]).to be_kind_of(RackExceptionAction::TestException)
  end

  it "doesn't reference error in rack.exception if it's handled" do
    action = HandledRackExceptionAction.new
    action.call(env)

    expect(env).to_not have_key("rack.exception")
  end

  it "doesn't reference of an error in rack.exception if it's handled" do
    action = HandledRackExceptionSubclassAction.new
    action.call(env)

    expect(env).to_not have_key("rack.exception")
  end
end
