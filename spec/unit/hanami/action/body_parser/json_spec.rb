# frozen_string_literal: true

RSpec.describe Hanami::Action::BodyParser::JSON, ".call" do
  it "parses valid JSON" do
    body = '{"user":{"name":"Alice","address":{"city":"Rome"}}}'
    result = described_class.call(body, {})

    expect(result).to eq(
      "user" => {
        "name" => "Alice",
        "address" => {"city" => "Rome"}
      }
    )
  end

  it "parses JSON arrays" do
    body = '[{"id":1},{"id":2}]'
    result = described_class.call(body, {})

    expect(result).to eq([{"id" => 1}, {"id" => 2}])
  end

  it "parses empty JSON object" do
    body = "{}"
    result = described_class.call(body, {})

    expect(result).to eq({})
  end

  it "raises BodyParsingError on invalid JSON" do
    body = "{invalid json}"

    expect {
      described_class.call(body, {})
    }.to raise_error(Hanami::Action::BodyParsingError)
  end
end
