# frozen_string_literal: true

RSpec.describe "MIME Type" do
  describe "Content type" do
    let(:app) { Rack::MockRequest.new(Mimes::Application.new) }

    it 'fallbacks to the default "Content-Type" header when the request is lacking of this information' do
      response = app.get("/")
      expect(response.headers["Content-Type"]).to eq("application/octet-stream; charset=utf-8")
      expect(response.body).to                    eq("all")
    end

    it 'returns the specified "Content-Type" header' do
      response = app.get("/custom")
      expect(response.headers["Content-Type"]).to eq("application/xml; charset=utf-8")
      expect(response.body).to                    eq("xml")
    end

    it "returns the custom charser header" do
      response = app.get("/latin")
      expect(response.headers["Content-Type"]).to eq("text/html; charset=latin1")
      expect(response.body).to                    eq("html")
    end

    # FIXME: Review if this test must be in place
    it 'does not produce a "Content-Type" header when the request has a 204 No Content status' do
      response = app.get("/nocontent")
      expect(response.headers).to_not have_key("Content-Type")
      expect(response.body).to        eq("")
    end

    context "when ACCEPT header is set and no format is configured" do
      it 'sets "Content-Type" header according to wildcard value' do
        response = app.get("/", "HTTP_ACCEPT" => "*/*")
        expect(response.headers["Content-Type"]).to eq("application/octet-stream; charset=utf-8")
        expect(response.body).to                    eq("all")
      end
    end

    context "when no ACCEPT or Content-Type are sent but there is a format configured" do
      it "accepts the request and sets the status to 200" do
        response = app.get("/custom_from_accept")
        expect(response.status).to eq 200
      end
    end

    context "when Content-Type are sent and there is a format configured" do
      it 'accepts the request and sets the response "Content-Type" to the default format' do
        response = app.get("/custom_from_accept", "CONTENT_TYPE" => "application/custom")
        expect(response.status).to eq 200
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        expect(response.body).to eq("json")
      end

      it "sets status to 415 if Content-Type does not match" do
        response = app.get("/custom_from_accept", "CONTENT_TYPE" => "application/xml")
        expect(response.status).to eq(415)
      end
    end

    context "when uploading a file to an action with format multipart/form-data configured" do
      it "does not return 415 for valid multipart/form-data request with boundary" do
        response = app.post("/upload", "CONTENT_TYPE" => "multipart/form-data; boundary=----abc123")

        expect(response.status).to eq(200)
        expect(response.body).to eq("multipart/form-data; boundary=----abc123")
      end
    end

    context "when Content-Type are sent and formats are configured to accept all" do
      it "accepts the request with a custom content type" do
        response = app.get("/relaxed", "CONTENT_TYPE" => "application/custom")
        expect(response.status).to eq 200
      end
    end

    context "when ACCEPT and Content-Type are sent and a format is configured" do
      it 'sets "Content-Type" header according to exact value' do
        response = app.get("/custom_from_accept", "HTTP_ACCEPT" => "application/custom")
        expect(response.headers["Content-Type"]).to eq("application/custom; charset=utf-8")
        expect(response.body).to                    eq("custom")
      end

      it %(sets the "Content-Type" header to the format's canonical media type) do
        response = app.get("/custom_from_accept", "HTTP_ACCEPT" => "application/custom+variant")
        expect(response.headers["Content-Type"]).to eq("application/custom; charset=utf-8")
        expect(response.body).to                    eq("custom")
      end

      it 'sets "Content-Type" header according to weighted value' do
        response = app.get("/custom_from_accept", "HTTP_ACCEPT" => "application/custom;q=0.9,application/json;q=0.5")
        expect(response.headers["Content-Type"]).to eq("application/custom; charset=utf-8")
        expect(response.body).to                    eq("custom")
      end

      it 'sets "Content-Type" header according to weighted, unordered value' do
        response = app.get("/custom_from_accept", "HTTP_ACCEPT" => "application/custom;q=0.1, application/json;q=0.5")
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        expect(response.body).to                    eq("json")
      end
    end

    context "when ACCEPT and Content-Type are send and there is no format configured" do
      it 'sets "Content-Type" header according to exact and weighted value' do
        response = app.get("/", "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        expect(response.headers["Content-Type"]).to eq("text/html; charset=utf-8")
        expect(response.body).to                    eq("html")
      end

      it 'sets "Content-Type" header according to quality scale value' do
        response = app.get("/", "HTTP_ACCEPT" => "application/json;q=0.6,application/xml;q=0.9,*/*;q=0.8")
        expect(response.headers["Content-Type"]).to eq("application/xml; charset=utf-8")
        expect(response.body).to                    eq("xml")
      end
    end

    # See https://github.com/hanami/hanami-action/issues/225
    context "with an accepted format and default response format" do
      let(:app) { Rack::MockRequest.new(MimesWithDefault::Application.new) }
      let(:response) { app.get("/default_and_accept", "CONTENT_TYPE" => "application/json") }

      it "defaults to the accepted format" do
        expect(response.status).to be(200)
        expect(response.body).to eq("html")
      end
    end

    context "with an accepted format" do
      it "accepts the matching format" do
        response = app.get("/strict", "HTTP_ACCEPT" => "application/json")
        expect(response.status).to eq(200)
        expect(response.headers["Content-Type"]).to eq("application/json; charset=utf-8")
        expect(response.body).to eq("json")
      end

      it "does not accept an unmatched format" do
        response = app.get("/strict", "HTTP_ACCEPT" => "application/xml")
        expect(response.status).to be(406)
      end
    end
  end

  describe "Accept" do
    let(:app)      { Rack::MockRequest.new(Mimes::Application.new) }
    let(:response) { app.get("/accept", "HTTP_ACCEPT" => accept) }

    context "when Accept is missing" do
      let(:accept) { nil }

      it "accepts all" do
        expect(response.headers["X-AcceptDefault"]).to eq("true")
        expect(response.headers["X-AcceptHtml"]).to    eq("true")
        expect(response.headers["X-AcceptXml"]).to     eq("true")
        expect(response.headers["X-AcceptJson"]).to    eq("true")
        expect(response.body).to                       eq("all")
      end
    end

    context "when Accept is sent" do
      context 'when "*/*"' do
        let(:accept) { "*/*" }

        it "accepts all" do
          expect(response.headers["X-AcceptDefault"]).to eq("true")
          expect(response.headers["X-AcceptHtml"]).to    eq("true")
          expect(response.headers["X-AcceptXml"]).to     eq("true")
          expect(response.headers["X-AcceptJson"]).to    eq("true")
          expect(response.body).to                       eq("all")
        end
      end

      context 'when "text/html"' do
        let(:accept) { "text/html" }

        it "accepts selected mime types" do
          expect(response.headers["X-AcceptDefault"]).to eq("false")
          expect(response.headers["X-AcceptHtml"]).to    eq("true")
          expect(response.headers["X-AcceptXml"]).to     eq("false")
          expect(response.headers["X-AcceptJson"]).to    eq("false")
          expect(response.body).to                       eq("html")
        end
      end

      context "when weighted" do
        let(:accept) { "text/html,application/xhtml+xml,application/xml;q=0.9" }

        it "accepts selected mime types" do
          expect(response.headers["X-AcceptDefault"]).to eq("false")
          expect(response.headers["X-AcceptHtml"]).to    eq("true")
          expect(response.headers["X-AcceptXml"]).to     eq("true")
          expect(response.headers["X-AcceptJson"]).to    eq("false")
          expect(response.body).to                       eq("html")
        end
      end

      context "applies the weighting mechanism for media ranges" do
        let(:accept) { "text/*,application/json,text/html,*/*" }

        it "accepts selected mime types" do
          expect(response.headers["X-AcceptDefault"]).to eq("true")
          expect(response.headers["X-AcceptHtml"]).to    eq("true")
          expect(response.headers["X-AcceptXml"]).to     eq("true")
          expect(response.headers["X-AcceptJson"]).to    eq("true")
          expect(response.body).to                       eq("json")
        end
      end
    end
  end
end
