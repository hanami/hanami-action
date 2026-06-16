# frozen_string_literal: true

require "stringio"

RSpec.describe Hanami::Action::BodyParser::MultipartForm, ".call" do
  it "parses multipart form data" do
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    body = [
      "------WebKitFormBoundary7MA4YWxkTrZu0gW",
      'Content-Disposition: form-data; name="title"',
      "",
      "My Title",
      "------WebKitFormBoundary7MA4YWxkTrZu0gW",
      'Content-Disposition: form-data; name="body"',
      "",
      "My Body",
      "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
    ].join("\r\n")

    env = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
      "CONTENT_LENGTH" => body.bytesize.to_s,
      Rack::RACK_INPUT => StringIO.new(body)
    }

    result = described_class.call(body, env)

    expect(result).to eq("title" => "My Title", "body" => "My Body")
  end

  it "parses file uploads" do
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    file_content = "file content here"
    body = [
      "------WebKitFormBoundary7MA4YWxkTrZu0gW",
      'Content-Disposition: form-data; name="upload"; filename="test.txt"',
      "Content-Type: text/plain",
      "",
      file_content,
      "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
    ].join("\r\n")

    env = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}",
      "CONTENT_LENGTH" => body.bytesize.to_s,
      Rack::RACK_INPUT => StringIO.new(body)
    }

    result = described_class.call(body, env)

    expect(result).to have_key("upload")
    upload = result["upload"]

    # Rack 3 returns a hash with :tempfile key
    if upload.is_a?(Hash)
      expect(upload[:tempfile]).to respond_to(:read)
      expect(upload[:tempfile].read).to eq(file_content)
    else
      # Rack 2 compatibility
      expect(upload).to respond_to(:read)
      expect(upload.read).to eq(file_content)
    end
  end

  it "raises BodyParsingError on invalid multipart data" do
    body = "not valid multipart data"

    env = {
      "CONTENT_TYPE" => "multipart/form-data; boundary=invalid",
      "CONTENT_LENGTH" => body.bytesize.to_s,
      Rack::RACK_INPUT => StringIO.new(body)
    }

    expect {
      described_class.call(body, env)
    }.to raise_error(Hanami::Action::BodyParsingError)
  end
end
