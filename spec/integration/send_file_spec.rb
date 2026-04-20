# frozen_string_literal: true

require "rack/test"

RSpec.describe "Full stack application" do
  include Rack::Test::Methods

  def app
    SendFileTest::Application.new
  end

  def response
    last_response
  end

  context "send files from anywhere in the system" do
    it "responds 200 when a local file exists" do
      get "/files/unsafe_local", {}
      file = Pathname.new("Gemfile")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("text/plain")
      expect(response.body.size).to                      eq(file.size)
    end

    it "responds 200 when a relative path file exists" do
      get "/files/unsafe_public", {}
      file = Pathname.new("spec/support/fixtures/test.txt")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("text/plain")
      expect(response.body.size).to                      eq(file.size)
    end

    it "responds 200 when an absoute path file exists" do
      get "/files/unsafe_absolute", {}
      file = Pathname.new("Gemfile")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("text/plain")
      expect(response.body.size).to                      eq(file.size)
    end

    it "responds 404 when a relative path does not exists" do
      get "/files/unsafe_missing_local", {}
      body = "Not Found"

      expect(response.status).to                         be(404)
      expect(response.headers["Content-Length"].to_i).to eq(body.bytesize)
      expect(response.headers["Content-Type"]).to        eq("text/plain")
      expect(response.body).to                           eq(body)
    end

    it "responds 404 when an absolute path does not exists" do
      get "/files/unsafe_missing_absolute", {}
      body = "Not Found"

      expect(response.status).to                         be(404)
      expect(response.headers["Content-Length"].to_i).to eq(body.bytesize)
      expect(response.headers["Content-Type"]).to        eq("text/plain")
      expect(response.body).to                           eq(body)
    end
  end

  context "when file exists, app responds 200" do
    it "sets Content-Type according to file type" do
      get "/files/1", {}
      file = Pathname.new("spec/support/fixtures/test.txt")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("text/plain")
      expect(response.body.size).to                      eq(file.size)
    end

    it "sets Content-Type according to file type (ignoring HTTP_ACCEPT)" do
      get "/files/2", {}, "HTTP_ACCEPT" => "text/html"
      file = Pathname.new("spec/support/fixtures/hanami.png")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("image/png")
      expect(response.body.size).to                      eq(file.size)
    end

    it "doesn't send file in case of HEAD request" do
      head "/files/1", {}

      expect(response.status).to be(200)
      expect(response.body).to be_empty
    end

    it "doesn't send file outside of public directory" do
      get "/files/3", {}

      expect(response.status).to be(404)
    end
  end

  context "if file doesn't exist" do
    it "responds 404" do
      get "/files/100", {}

      expect(response.status).to be(404)
      expect(response.body).to   eq("Not Found")
    end
  end

  context "using conditional glob routes and :format" do
    it "serves up json" do
      get "/files/500.json", {}

      file = Pathname.new("spec/support/fixtures/resource-500.json")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("application/json")
      expect(response.body.size).to                      eq(file.size)
    end

    it "fails on an unknown format" do
      get "/files/500.xml", {}

      expect(response.status).to be(406)
    end

    it "serves up html" do
      get "/files/500.html", {}

      file = Pathname.new("spec/support/fixtures/resource-500.html")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("text/html; charset=utf-8")
      expect(response.body.size).to                      eq(file.size)
    end

    it "works without a :format" do
      get "/files/500", {}

      file = Pathname.new("spec/support/fixtures/resource-500.json")

      expect(response.status).to                         be(200)
      expect(response.headers["Content-Length"].to_i).to eq(file.size)
      expect(response.headers["Content-Type"]).to        eq("application/json")
      expect(response.body.size).to                      eq(file.size)
    end

    it "returns 400 when I give a bogus id" do
      get "/files/not-an-id.json", {}

      expect(response.status).to be(400)
    end

    it "blows up when :format is sent as an :id" do
      get "/files/501.json", {}

      expect(response.status).to be(404)
    end
  end

  context "Conditional GET request" do
    it "shouldn't send file" do
      if_modified_since = File.mtime("spec/support/fixtures/test.txt").httpdate
      get "/files/1", {}, "HTTP_ACCEPT" => "text/html", "HTTP_IF_MODIFIED_SINCE" => if_modified_since

      expect(response.status).to      be(304)
      expect(response.headers).to_not have_key("Content-Length")
      expect(response.headers).to_not have_key("Content-Type")
      expect(response.body).to        be_empty
    end
  end

  context "bytes range" do
    it "sends ranged contents" do
      get "/files/1", {}, "HTTP_RANGE" => "bytes=5-13"

      expect(response.status).to                    be(206)
      expect(response.headers["Content-Length"]).to eq("9")
      expect(response.headers["Content-Range"]).to  eq("bytes 5-13/69")
      expect(response.body).to                      eq("Text File")
    end
  end

  it "interrupts the control flow" do
    get "/files/flow", {}
    expect(response.status).to be(200)
  end

  it "runs 'before' callbacks" do
    get "/files/before_callback"

    expect(response.status).to                    be(200)
    expect(response.headers["Content-Length"]).to eq("69")
    expect(response.headers["X-Callbacks"]).to    eq("before")
  end

  it "runs 'after' callbacks" do
    get "/files/after_callback"

    expect(response.status).to                    be(200)
    expect(response.headers["Content-Length"]).to eq("69")
    expect(response.headers["X-Callbacks"]).to    eq("after")
  end
end
