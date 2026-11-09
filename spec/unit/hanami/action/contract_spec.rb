# frozen_string_literal: true

require "rack"

RSpec.describe "Contract" do
  describe "defined inline in action" do
    let(:action) { ContractAction.new }

    context "when it has errors" do
      it "returns them" do
        response = action.call("birth_date" => "2000-01-01")

        expect(response.status).to eq 302

        if RUBY_VERSION < "3.4"
          expect(response.body).to eq ["{:errors=>{:book=>[\"is missing\"], :birth_date=>[\"you must be 18 years or older\"]}}"]
        else
          expect(response.body).to eq ["{errors: {book: [\"is missing\"], birth_date: [\"you must be 18 years or older\"]}}"]
        end
      end
    end

    context "when it is valid" do
      it "works" do
        response = action.call("birth_date" => Date.today - (365 * 15), "book" => {"title" => "Hanami"})

        expect(response.status).to eq 201
        expect(response.body).to eq ["{\"new_name\":\"HANAMI\"}"]
      end
    end
  end

  describe "provided by a standlone contract class" do
    let(:action) { ExternalContractAction.new }

    context "when it has errors" do
      it "returns them" do
        response = action.call("birth_date" => "2000-01-01")

        expect(response.status).to eq 302

        if RUBY_VERSION < "3.4"
          expect(response.body).to eq ["{:errors=>{:book=>[\"is missing\"], :birth_date=>[\"you must be 18 years or older\"]}}"]
        else
          expect(response.body).to eq ["{errors: {book: [\"is missing\"], birth_date: [\"you must be 18 years or older\"]}}"]
        end
      end
    end

    context "when it is valid" do
      it "works" do
        response = action.call("birth_date" => Date.today - (365 * 15), "book" => {"title" => "Hanami"})

        expect(response.status).to eq 201
        expect(response.body).to eq ["{\"new_name\":\"HANAMI\"}"]
      end
    end
  end

  describe "provided by an injected contract dependency" do
    let(:action) { DependencyContractAction.new(contract: ExternalContract.new) }

    context "when it has errors" do
      it "returns them" do
        response = action.call("birth_date" => "2000-01-01")

        expect(response.status).to eq 302

        if RUBY_VERSION < "3.4"
          expect(response.body).to eq ["{:errors=>{:book=>[\"is missing\"], :birth_date=>[\"you must be 18 years or older\"]}}"]
        else
          expect(response.body).to eq ["{errors: {book: [\"is missing\"], birth_date: [\"you must be 18 years or older\"]}}"]
        end
      end
    end

    context "when it is valid" do
      it "works" do
        response = action.call("birth_date" => Date.today - (365 * 15), "book" => {"title" => "Hanami"})

        expect(response.status).to eq 201
        expect(response.body).to eq ["{\"new_name\":\"HANAMI\"}"]
      end
    end
  end

  describe "#raw" do
    context "without a contract" do
      let(:action) { RawContractAction.new }

      it "raw gets all params" do
        File.open("spec/support/fixtures/multipart-upload.png", "rb") do |upload|
          response = action.call("id" => "1", "unknown" => "2", "upload" => upload)

          expect(response[:params][:id]).to eq("1")
          expect(response[:params][:unknown]).to eq("2")
          expect(FileUtils.cmp(response[:params][:upload], upload)).to be(true)

          expect(response[:params].raw.fetch("id")).to eq("1")
          expect(response[:params].raw.fetch("unknown")).to eq("2")
          expect(response[:params].raw.fetch("upload")).to eq(upload)
        end
      end
    end

    context "with a contract" do
      let(:action) { AllowlistedUploadDslContractAction.new }

      it "raw gets all params" do
        Tempfile.create("multipart-upload") do |upload|
          response = action.call("id" => "1", "unknown" => "2", "upload" => upload, "_csrf_token" => "3")

          expect(response[:params][:id]).to          eq(1)
          expect(response[:params][:unknown]).to     be(nil)
          expect(response[:params][:upload]).to      eq(upload)

          expect(response[:params].raw.fetch("id")).to          eq("1")
          expect(response[:params].raw.fetch("unknown")).to     eq("2")
          expect(response[:params].raw.fetch("upload")).to      eq(upload)
        end
      end
    end
  end

  describe "keys nested in a hash the contract does not describe" do
    let(:action) do
      Class.new(Hanami::Action) do
        contract do
          params do
            required(:title).filled(:string)
            optional(:details).maybe(:hash)
          end
        end

        def handle(req, res)
          res.body = req.params.to_h.inspect
        end
      end.new
    end

    it "symbolizes them like the rest of the params" do
      response = action.call("title" => "Hanami", "details" => {"pages" => "300"})

      expect(response[:params].to_h).to eq(title: "Hanami", details: {pages: "300"})
      expect(response[:params].raw.fetch("details")).to eq("pages" => "300")
    end
  end
end
