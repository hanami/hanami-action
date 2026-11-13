# frozen_string_literal: true

RSpec.describe Hanami::Action::Config do
  subject(:config) { Class.new(Hanami::Action).config }

  describe "#handled_exceptions" do
    it "handles body and params parsing errors as 400 Bad Request by default" do
      expect(config.handled_exceptions).to eq(
        Hanami::Action::BodyParsingError => 400,
        Hanami::Action::ParamsParsingError => 400
      )
    end

    it "allows specifying a complete set of exceptions" do
      config.handled_exceptions = {ArgumentError => 400}
      expect(config.handled_exceptions).to eq(ArgumentError => 400)
    end

    it "allows adding individual exceptions" do
      config.handle_exception ArgumentError => 400
      expect(config.handled_exceptions).to include(ArgumentError => 400)

      config.handle_exception TypeError => 400
      expect(config.handled_exceptions).to include(ArgumentError => 400, TypeError => 400)
    end

    it "allows specifying multiple exceptions as strings" do
      config.handled_exceptions = {
        "ArgumentError" => 400,
        "TypeError" => 400
      }
      expect(config.handled_exceptions).to eq(
        "ArgumentError" => 400,
        "TypeError" => 400
      )
    end
  end

  describe "#default_charset" do
    it "is nil by default" do
      expect(config.default_charset).to be nil
    end

    it "can be set with a charset string" do
      config.default_charset = "latin1"
      expect(config.default_charset).to eq("latin1")
    end
  end

  describe "#default_headers" do
    it "is an empty hash by default" do
      expect(config.default_headers).to eq({})
    end

    it "can be set with a headers hash" do
      config.default_headers = {"X-Frame-Options" => "DENY"}
      expect(config.default_headers).to eq("X-Frame-Options" => "DENY")
    end

    it "rejects headers with nil values" do
      config.default_headers = {"X-Nil" => nil}
      expect(config.default_headers).to eq({})
    end
  end

  describe "#default_tld_length" do
    it "is 1 by default" do
      expect(config.default_tld_length).to be(1)
    end

    it "can be set with an integer" do
      config.default_tld_length = 2
      expect(config.default_tld_length).to be(2)
    end
  end

  describe "#cookies" do
    it "is an empty hash by default" do
      expect(config.cookies).to eq({})
    end

    it "can be set with a cookie config hash" do
      config.cookies = {domain: "hanamirb.org", secure: true}
      expect(config.cookies).to eq(domain: "hanamirb.org", secure: true)
    end

    it "rejects nil values" do
      config.cookies = {domain: nil}
      expect(config.cookies).to eq({})
    end
  end

  describe "#root_directory" do
    it "is the current working directory by default" do
      expect(config.root_directory).to be_a Pathname
      expect(config.root_directory.to_s).to eq Dir.pwd
    end

    it "can be set with another directory" do
      config.root_directory = __dir__

      expect(config.root_directory).to be_a Pathname
      expect(config.root_directory.to_s).to eq __dir__
    end
  end

  describe "#public_directory" do
    let(:root_directory) { __dir__ }

    before do
      config.root_directory = __dir__
    end

    it "returns the public/ within the root directory by default" do
      expect(config.public_directory).to eql(File.join(root_directory, "public"))
    end

    it "can be set with a relative path" do
      config.public_directory = "static"
      expect(config.public_directory).to eql(File.join(root_directory, "static"))
    end

    it "can be set with an abolute path" do
      config.public_directory = File.join(__dir__, "absolute")
      expect(config.public_directory).to eql(File.join(root_directory, "absolute"))
    end
  end
end
