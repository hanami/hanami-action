# frozen_string_literal: true

RSpec.describe Hanami::Action do
  class FormatActions
    class Lookup < Hanami::Action
      def handle(*)
      end
    end

    class Custom < Hanami::Action
      def handle(req, res)
        input = req.params[:format]
        input = input.to_sym unless input.nil?

        res.format = input
      end
    end

    class Configuration < Hanami::Action
      config.formats.accept :jpg

      def handle(*, res)
        res.body = res.format
      end
    end
  end

  describe "#format" do
    let(:action) { FormatActions::Lookup.new }

    it "lookup to #content_type if was not explicitly set (default: application/octet-stream)" do
      response = action.call({})

      expect(response.format).to                  eq(:all)
      expect(response.headers["Content-Type"]).to eq("application/octet-stream; charset=utf-8")
      expect(response.status).to                  be(200)
    end

    it "accepts 'text/html' and returns :html" do
      response = action.call("HTTP_ACCEPT" => "text/html")

      expect(response.format).to                  eq(:html)
      expect(response.headers["Content-Type"]).to eq("text/html; charset=utf-8")
      expect(response.status).to                  be(200)
    end

    it "accepts unknown mime type and returns :all" do
      response = action.call("HTTP_ACCEPT" => "application/unknown")

      expect(response.format).to                  eq(:all)
      expect(response.headers["Content-Type"]).to eq("application/octet-stream; charset=utf-8")
      expect(response.status).to                  be(200)
    end

    # Bug
    # See https://github.com/hanami/hanami-action/issues/104
    it "accepts 'text/html, application/xhtml+xml, image/jxr, */*' and returns :html" do
      response = action.call("HTTP_ACCEPT" => "text/html, application/xhtml+xml, image/jxr, */*")

      expect(response.format).to                  eq(:html)
      expect(response.headers["Content-Type"]).to eq("text/html; charset=utf-8")
      expect(response.status).to                  be(200)
    end

    # Bug
    # See https://github.com/hanami/hanami-action/issues/167
    it "accepts '*/*' and returns configured default format" do
      action = FormatActions::Configuration.new
      response = action.call("HTTP_ACCEPT" => "*/*")

      expect(response.format).to                  eq(:jpg)
      expect(response.headers["Content-Type"]).to eq("image/jpeg; charset=utf-8")
      expect(response.status).to                  be(200)
    end

    Hanami::Action::Mime::TYPES.each do |format, mime_type|
      it "accepts '#{mime_type}' and returns :#{format}" do
        response = action.call("HTTP_ACCEPT" => mime_type)

        expect(response.format).to                  eq(format)
        expect(response.headers["Content-Type"]).to eq("#{mime_type}; charset=utf-8")
        expect(response.status).to                  be(200)
      end
    end
  end

  describe "#format=" do
    let(:action) { FormatActions::Custom.new }

    it "sets :all and returns 'application/octet-stream'" do
      response = action.call(format: "all")

      expect(response.format).to                  eq(:all)
      expect(response.headers["Content-Type"]).to eq("application/octet-stream; charset=utf-8")
      expect(response.status).to                  be(200)
    end

    it "sets nil and raises an error" do
      expected_message = <<~MSG
        Cannot find a corresponding MIME type for format `nil'.
      MSG

      expect { action.call(format: nil) }.to raise_error do |exception|
        expect(exception).to         be_kind_of(Hanami::Action::UnknownFormatError)
        expect(exception.message).to eq(expected_message)
      end
    end

    it "sets '' and raises an error" do
      expected_message = <<~MSG
        Cannot find a corresponding MIME type for format `:""'.
      MSG

      expect { action.call(format: "") }.to raise_error do |exception|
        expect(exception).to         be_kind_of(Hanami::Action::UnknownFormatError)
        expect(exception.message).to eq(expected_message)
      end
    end

    it "sets an unknown format and raises an error" do
      expected_message = <<~MSG
        Cannot find a corresponding MIME type for format `:unknown'.

        Configure one via: `config.actions.formats.add(:unknown, "MIME_TYPE_HERE")' in `config/app.rb' to share between actions of a Hanami app.

        Or make it available only in the current action: `config.formats.add(:unknown, "MIME_TYPE_HERE")'.
      MSG

      expect { action.call(format: :unknown) }.to raise_error do |exception|
        expect(exception).to         be_kind_of(Hanami::Action::UnknownFormatError)
        expect(exception.message).to eq(expected_message)
      end
    end

    Hanami::Action::Mime::TYPES.each do |format, mime_type|
      it "sets #{format} and returns '#{mime_type}'" do
        response = action.call(format: format)

        expect(response.format).to                  eq(format)
        expect(response.headers["Content-Type"]).to eq("#{mime_type}; charset=utf-8")
      end
    end
  end
end
