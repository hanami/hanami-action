# frozen_string_literal: true

RSpec.describe Hanami::Action::Config::Formats do
  subject(:formats) { described_class.new }

  describe "#register" do
    it "registers a mapping" do
      expect { formats.register(:custom, "application/custom") }
        .to change { formats.mapping }
        .to include(custom: have_attributes(media_type: "application/custom"))
    end

    it "registers a mapping with content types" do
      expect {
        formats.register(
          :jsonapi,
          "application/vnd.api+json",
          accept_types: ["application/vnd.api+json", "application/json"],
          content_types: ["application/vnd.api+json", "application/json"]
        )
      }
        .to change { formats.mapping }
        .to include(
          jsonapi: have_attributes(
            media_type: "application/vnd.api+json",
            accept_types: ["application/vnd.api+json", "application/json"],
            content_types: ["application/vnd.api+json", "application/json"]
          )
        )
    end

    it "registers parser for content types" do
      parser = ->(body, env) { {"parsed" => true} }

      formats.register(:custom, "application/custom", parser: parser)

      expect(formats.body_parser_for("application/custom")).to eq(parser)
    end

    it "registers parser for multiple content types" do
      parser = ->(body, env) { {"parsed" => true} }

      formats.register(
        :custom,
        "application/custom",
        content_types: ["application/custom", "application/x-custom"],
        parser: parser
      )

      expect(formats.body_parser_for("application/custom")).to eq(parser)
      expect(formats.body_parser_for("application/x-custom")).to eq(parser)
    end

    it "normalizes content type case when registering parser" do
      parser = ->(body, env) { {"parsed" => true} }

      formats.register(:custom, "Application/Custom", parser: parser)

      expect(formats.body_parser_for("application/custom")).to eq(parser)
      expect(formats.body_parser_for("APPLICATION/CUSTOM")).to eq(parser)
    end
  end

  describe "#accepted" do
    it "returns an empty array by default" do
      expect(formats.accepted).to eq []
    end

    it "returns the formats configured by #accept" do
      expect { formats.accept :json }
        .to change { formats.accepted }
        .to [:json]
    end

    it "can be assigned with an array of formats" do
      expect { formats.accepted = [:json, :html] }
        .to change { formats.accepted }
        .to [:json, :html]
    end
  end

  describe "#body_parsers" do
    it "is exposed as an attribute" do
      expect(formats.body_parsers).to be_a(Hash)
    end

    it "allows direct parser registration" do
      parser = ->(body, env) { {"direct" => true} }
      formats.body_parsers["application/direct"] = parser

      expect(formats.body_parser_for("application/direct")).to eq(parser)
    end

    it "includes default parsers for JSON" do
      expect(formats.body_parser_for("application/json")).to eq(Hanami::Action::BodyParser::JSON)
      expect(formats.body_parser_for("application/vnd.api+json")).to eq(Hanami::Action::BodyParser::JSON)
    end

    it "includes default parser for multipart forms" do
      expect(formats.body_parser_for("multipart/form-data")).to eq(Hanami::Action::BodyParser::MultipartForm)
    end
  end

  describe "#body_parser_for" do
    it "returns parser for registered content type" do
      parser = formats.body_parser_for("application/json")

      expect(parser).to eq(Hanami::Action::BodyParser::JSON)
    end

    it "returns nil for unregistered content type" do
      expect(formats.body_parser_for("application/unknown")).to be_nil
    end

    it "is case-insensitive" do
      parser = formats.body_parser_for("APPLICATION/JSON")

      expect(parser).to eq(Hanami::Action::BodyParser::JSON)
    end

    it "handles nil content type" do
      expect(formats.body_parser_for(nil)).to be_nil
    end
  end

  describe "#accept" do
    it "sets the list of accepted formats" do
      expect { formats.accept :json, :html }
        .to change { formats.accepted }
        .to [:json, :html]
    end

    it "appends to the list of accepted formats when called more than once" do
      expect { formats.accept :json }
        .to change { formats.accepted }
        .to([:json])

      expect { formats.accept :html }
        .to change { formats.accepted }
        .to([:json, :html])

      expect { formats.accept :json, :custom }
        .to change { formats.accepted }
        .to [:json, :html, :custom]
    end

    it "sets the default format to the first format, when no default is set" do
      expect { formats.accept :json }
        .to change { formats.default }
        .to :json
    end

    it "does not change the default format when it has already been set" do
      formats.default = :html

      expect { formats.accept :json }
        .not_to change { formats.default }
        .from :html
    end
  end

  describe "#default" do
    it "returns nil by default" do
      expect(formats.default).to be nil
    end

    it "can be assigned to a format" do
      expect { formats.default = :json }
        .to change { formats.default }
        .to :json
    end
  end

  describe "#clear" do
    it "clears any previously assigned mappings and values" do
      formats.register(:custom, "application/custom")
      formats.accepted = [:custom]

      formats.clear

      expect(formats.mapping.keys).not_to include "application/custom"
      expect(formats.accepted).to eq []
    end
  end

  describe "#format_for" do
    before do
      formats.register(:html, "text/html")
    end

    it "returns the configured format for the given MIME type" do
      expect(formats.format_for("text/html")).to eq :html
    end

    it "returns the most recently configured format for a given MIME type" do
      formats.register :htm, "text/html"

      expect(formats.format_for("text/html")).to eq(:htm)
    end

    it "returns nil if no matching format is found" do
      expect(formats.format_for("*/*")).to be nil
    end
  end

  describe "#media_type_for" do
    before do
      formats.register(:custom, "application/custom")
    end

    it "returns the configured media type for the given format" do
      expect(formats.media_type_for(:custom)).to eq "application/custom"
    end

    it "returns nil if no matching format is found" do
      expect(formats.mime_type_for(:missing)).to be nil
    end
  end
end
