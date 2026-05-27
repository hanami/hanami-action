# frozen_string_literal: true

require "rack"

RSpec.describe Hanami::Action::Params do
  describe "#raw" do
    let(:params) { Class.new(Hanami::Action::Params) }

    context "when this feature isn't enabled" do
      let(:action) { ParamsAction.new }

      it "raw gets all params" do
        File.open("spec/support/fixtures/multipart-upload.png", "rb") do |upload|
          response = action.call("id" => "1", "unknown" => "2", "upload" => upload, "_csrf_token" => "3")

          expect(response[:params][:id]).to eq("1")
          expect(response[:params][:unknown]).to eq("2")
          expect(FileUtils.cmp(response[:params][:upload], upload)).to be(true)
          expect(response[:params][:_csrf_token]).to eq("3")

          expect(response[:params].raw.fetch("id")).to eq("1")
          expect(response[:params].raw.fetch("unknown")).to eq("2")
          expect(response[:params].raw.fetch("upload")).to eq(upload)
          expect(response[:params].raw.fetch("_csrf_token")).to eq("3")
        end
      end
    end

    context "when this feature is enabled" do
      let(:action) { AllowlistedUploadDslAction.new }

      it "raw gets all params" do
        Tempfile.create("multipart-upload") do |upload|
          response = action.call("id" => "1", "unknown" => "2", "upload" => upload, "_csrf_token" => "3")

          expect(response[:params][:id]).to          eq(1)
          expect(response[:params][:unknown]).to     be(nil)
          expect(response[:params][:upload]).to      eq(upload)

          expect(response[:params].raw.fetch("id")).to          eq("1")
          expect(response[:params].raw.fetch("unknown")).to     eq("2")
          expect(response[:params].raw.fetch("upload")).to      eq(upload)
          expect(response[:params].raw.fetch("_csrf_token")).to eq("3")
        end
      end
    end
  end

  describe "allowlisting" do
    let(:params) { Class.new(Hanami::Action::Params) }

    context "when this feature isn't enabled" do
      let(:action) { ParamsAction.new }

      it "creates a Params innerclass" do
        expect(defined?(ParamsAction::Params)).to eq("constant")
        expect(ParamsAction::Params.ancestors).to include(Hanami::Action::Params)
      end

      context "in testing mode" do
        it "returns all the params as they are" do
          # For unit tests in Hanami projects, developers may want to define
          # params with symbolized keys.
          response = action.call(a: "1", b: "2", c: "3")

          if RUBY_VERSION < "3.4"
            expect(response.body).to eq([%({:a=>"1", :b=>"2", :c=>"3"})])
          else
            expect(response.body).to eq([%({a: "1", b: "2", c: "3"})])
          end
        end
      end

      context "in a Rack context" do
        it "returns all the params as they are" do
          # Rack params are always stringified
          response = Rack::MockRequest.new(action).request("PATCH", "?id=23", params: {"x" => {"foo" => "bar"}})

          if RUBY_VERSION < "3.4"
            expect(response.body).to eq(%({:id=>"23", :x=>{:foo=>"bar"}}))
          else
            expect(response.body).to eq(%({id: "23", x: {foo: "bar"}}))
          end
        end

        it "returns only query params for bodyless GET requests" do
          # Rack 3 omits rack.input for bodyless requests; env keys like REQUEST_METHOD,
          # SERVER_NAME, etc. must not leak into the params.
          response = Rack::MockRequest.new(action).request("GET", "/foo?id=23")

          if RUBY_VERSION < "3.4"
            expect(response.body).to eq(%({:id=>"23"}))
          else
            expect(response.body).to eq(%({id: "23"}))
          end
        end
      end
    end

    context "when this feature is enabled" do
      context "with an explicit class" do
        let(:action) { AllowlistedParamsAction.new }

        # For unit tests in Hanami projects, developers may want to define
        # params with symbolized keys.
        context "in testing mode" do
          it "returns only the listed params" do
            response = action.call(id: 23, unknown: 4, article: {foo: "bar", tags: [:cool]})

            if RUBY_VERSION < "3.4"
              expect(response.body).to eq([%({:id=>23, :article=>{:tags=>[:cool]}})])
            else
              expect(response.body).to eq([%({id: 23, article: {tags: [:cool]}})])
            end
          end

          it "removes _csrf_token" do
            response = action.call(_csrf_token: "abc")
            expect(response.body).to eq([%({})])
          end
        end

        context "in a Rack context" do
          it "returns only the listed params" do
            response = Rack::MockRequest.new(action).request("PATCH", "?id=23", params: {x: {foo: "bar"}})

            if RUBY_VERSION < "3.4"
              expect(response.body).to match(%({:id=>23}))
            else
              expect(response.body).to match(%({id: 23}))
            end
          end

          it "removes _csrf_token" do
            response = Rack::MockRequest.new(action).request("PATCH", "?id=1", params: {_csrf_token: "def", x: {foo: "bar"}})
            expect(response.body).not_to match("_csrf_token")

            if RUBY_VERSION < "3.4"
              expect(response.body).to match(%({:id=>1}))
            else
              expect(response.body).to match(%({id: 1}))
            end
          end
        end
      end

      context "with an anoymous class" do
        let(:action) { AllowlistedDslAction.new }

        it "creates a Params innerclass" do
          expect(defined?(AllowlistedDslAction::Params)).to eq("constant")
          expect(AllowlistedDslAction::Params.ancestors).to include(Hanami::Action::Params)
        end

        context "in testing mode" do
          it "returns only the listed params" do
            response = action.call(username: "jodosha", unknown: "field")

            if RUBY_VERSION < "3.4"
              expect(response.body).to eq([%({:username=>"jodosha"})])
            else
              expect(response.body).to eq([%({username: "jodosha"})])
            end
          end
        end

        context "in a Rack context" do
          it "returns only the listed params" do
            response = Rack::MockRequest.new(action).request("PATCH", "?username=jodosha", params: {x: {foo: "bar"}})

            if RUBY_VERSION < "3.4"
              expect(response.body).to match(%({:username=>"jodosha"}))
            else
              expect(response.body).to match(%({username: "jodosha"}))
            end
          end
        end
      end
    end
  end

  describe "validations" do
    it "isn't valid with empty params" do
      params = Hanami::Action::Params.new(contract: TestContract.new, env: {})

      expect(params.valid?).to be(false)

      expect(params.errors.fetch(:email)).to   eq(["is missing"])
      expect(params.errors.fetch(:name)).to    eq(["is missing"])
      expect(params.errors.fetch(:tos)).to     eq(["is missing"])
      expect(params.errors.fetch(:address)).to eq(["is missing"])

      expect(params.error_messages).to eq(["Email is missing", "Name is missing", "Tos is missing", "Age is missing", "Address is missing"])
    end

    it "isn't valid with empty nested params" do
      params = Hanami::Action::Params.new(env: {signup: {}}, contract: NestedContract.new)

      expect(params.valid?).to be(false)

      expect(params.errors.fetch(:signup).fetch(:name)).to eq(["is missing"])

      expect(params.error_messages).to eq(["Name is missing", "Age is missing"])
    end

    it "is it valid when all the validation criteria are met" do
      params = Hanami::Action::Params.new(
        contract: TestContract.new,
        env: {
          email: "test@hanamirb.org",
          password: "123456",
          password_confirmation: "123456",
          name: "Luca",
          tos: "1",
          age: "34",
          address: {
            line_one: "10 High Street",
            deep: {
              deep_attr: "blue"
            }
          }
        }
      )

      expect(params.valid?).to         be(true)
      expect(params.errors).to         be_empty
      expect(params.error_messages).to be_empty
    end

    it "has input available through the hash accessor" do
      params = Hanami::Action::Params.new(contract: TestContract.new, env: {name: "John", age: "1", address: {line_one: "10 High Street"}})

      expect(params[:name]).to               eq("John")
      expect(params[:age]).to                be(1)
      expect(params[:address][:line_one]).to eq("10 High Street")
    end

    it "allows nested hash access via symbols" do
      params = Hanami::Action::Params.new(contract: TestContract.new, env: {name: "John", address: {line_one: "10 High Street", deep: {deep_attr: 1}}})
      expect(params[:name]).to                       eq("John")
      expect(params[:address][:line_one]).to         eq("10 High Street")
      expect(params[:address][:deep][:deep_attr]).to be(1)
    end
  end

  describe "#get" do
    context "with data" do
      let(:params) do
        Hanami::Action::Params.new(
          contract: TestContract.new,
          env: {
            name: "John",
            address: {line_one: "10 High Street", deep: {deep_attr: 1}},
            array: [{name: "Lennon"}, {name: "Wayne"}]
          }
        )
      end

      it "returns nil for nil argument" do
        expect(params.get(nil)).to be(nil)
      end

      it "returns nil for unknown param" do
        expect(params.get(:unknown)).to be(nil)
      end

      it "allows to read top level param" do
        expect(params.get(:name)).to eq("John")
      end

      it "allows to read nested param" do
        expect(params.get(:address, :line_one)).to eq("10 High Street")
      end

      it "returns nil for uknown nested param" do
        expect(params.get(:address, :unknown)).to be(nil)
      end

      it "allows to read datas under arrays" do
        expect(params.get(:array, 0, :name)).to eq("Lennon")
        expect(params.get(:array, 1, :name)).to eq("Wayne")
      end
    end

    context "without data" do
      let(:params) { Hanami::Action::Params.new(contract: TestContract.new, env: {}) }

      it "returns nil for nil argument" do
        expect(params.get(nil)).to be(nil)
      end

      it "returns nil for unknown param" do
        expect(params.get(:unknown)).to be(nil)
      end

      it "returns nil for top level param" do
        expect(params.get(:name)).to be(nil)
      end

      it "returns nil for nested param" do
        expect(params.get(:address, :line_one)).to be(nil)
      end

      it "returns nil for uknown nested param" do
        expect(params.get(:address, :unknown)).to be(nil)
      end
    end
  end

  describe "#to_h" do
    let(:params) { Hanami::Action::Params.new(contract: TestContract.new, env: {name: "Jane"}) }

    it "returns a ::Hash" do
      expect(params.to_h).to be_kind_of(::Hash)
    end

    it "returns unfrozen Hash" do
      expect(params.to_h).to_not be_frozen
    end

    it "prevents informations escape"
    # it "prevents informations escape" do
    #   hash = params.to_h
    #   hash.merge!({name: 'L'})

    #   params.to_h).to eq((Hash['id' => '23'])
    # end

    it "handles nested params" do
      input = {
        "address" => {
          "deep" => {
            "deep_attr" => "foo"
          }
        }
      }

      expected = {
        address: {
          deep: {
            deep_attr: "foo"
          }
        }
      }

      actual = Hanami::Action::Params.new(contract: TestContract.new, env: input).to_h
      expect(actual).to eq(expected)

      expect(actual).to                  be_kind_of(::Hash)
      expect(actual[:address]).to        be_kind_of(::Hash)
      expect(actual[:address][:deep]).to be_kind_of(::Hash)
    end

    context "when allowlisting" do
      # This is bug 113.
      it "handles nested params" do
        input = {
          "name" => "John",
          "age" => 1,
          "address" => {
            "line_one" => "10 High Street",
            "deep" => {
              "deep_attr" => "hello"
            }
          }
        }

        expected = {
          name: "John",
          age: 1,
          address: {
            line_one: "10 High Street",
            deep: {
              deep_attr: "hello"
            }
          }
        }

        actual = Hanami::Action::Params.new(contract: TestContract.new, env: input).to_h
        expect(actual).to eq(expected)

        expect(actual).to                  be_kind_of(::Hash)
        expect(actual[:address]).to        be_kind_of(::Hash)
        expect(actual[:address][:deep]).to be_kind_of(::Hash)
      end
    end
  end

  describe "#to_hash" do
    let(:params) { Hanami::Action::Params.new(contract: TestContract.new, env: {name: "Jane"}) }

    it "returns a ::Hash" do
      expect(params.to_hash).to be_kind_of(::Hash)
    end

    it "returns unfrozen Hash" do
      expect(params.to_hash).to_not be_frozen
    end

    it "prevents informations escape"
    # it "prevents informations escape" do
    #   hash = params.to_hash
    #   hash.merge!({name: 'L'})

    #   params.to_hash).to eq((Hash['id' => '23'])
    # end

    it "handles nested params" do
      input = {
        "address" => {
          "deep" => {
            "deep_attr" => "foo"
          }
        }
      }

      expected = {
        address: {
          deep: {
            deep_attr: "foo"
          }
        }
      }

      actual = Hanami::Action::Params.new(contract: TestContract.new, env: input).to_hash
      expect(actual).to eq(expected)

      expect(actual).to                  be_kind_of(::Hash)
      expect(actual[:address]).to        be_kind_of(::Hash)
      expect(actual[:address][:deep]).to be_kind_of(::Hash)
    end

    context "when allowlisting" do
      # This is bug 113.
      it "handles nested params" do
        input = {
          "name" => "John",
          "age" => 1,
          "address" => {
            "line_one" => "10 High Street",
            "deep" => {
              "deep_attr" => "hello"
            }
          }
        }

        expected = {
          name: "John",
          age: 1,
          address: {
            line_one: "10 High Street",
            deep: {
              deep_attr: "hello"
            }
          }
        }

        actual = Hanami::Action::Params.new(contract: TestContract.new, env: input).to_hash
        expect(actual).to eq(expected)

        expect(actual).to                  be_kind_of(::Hash)
        expect(actual[:address]).to        be_kind_of(::Hash)
        expect(actual[:address][:deep]).to be_kind_of(::Hash)
      end

      it "does not stringify values" do
        input  = {"name" => 123}
        params = Hanami::Action::Params.new(contract: TestContract.new, env: input)

        expect(params[:name]).to be(123)
      end
    end
  end

  describe "#deconstruct_keys" do
    let(:params) do
      Hanami::Action::Params.new(
        contract: TestContract.new,
        env: {
          name: "John",
          address: {line_one: "10 High Street", deep: {deep_attr: 1}},
          array: [{name: "Lennon"}, {name: "Wayne"}]
        }
      )
    end

    it "supports pattern-matching" do
      params => {name:}
      expect(name).to eq("John")
    end
  end

  describe "#errors" do
    let(:contract) do
      Class.new(Dry::Validation::Contract) do
        params do
          required(:book).schema do
            required(:code).filled(:str?)
          end
        end
      end.new
    end

    let(:params) { described_class.new(env: {book: {code: "abc"}}, contract: contract) }

    it "returns Hanami::Action::Params::Errors" do
      expect(params.errors).to be_kind_of(Hanami::Action::Params::Errors)
    end

    it "alters the returning value of #valid?" do
      expect(params).to be_valid

      params.errors.add(:book, :code, "is not unique")
      expect(params).to_not be_valid
    end

    it "appends message to already existing messages" do
      params = described_class.new(env: {book: {}}, contract: contract)
      params.errors.add(:book, :code, "is invalid")

      expect(params.error_messages).to eq(["Code is missing", "Code is invalid"])
    end

    it "gets listed in #error_messages" do
      params.errors.add(:book, :code, "is not unique")
      expect(params.error_messages).to eq(["Code is not unique"])
    end

    it "raises error when try to add an error " do
      params = described_class.new(env: {}, contract: contract)

      if RUBY_VERSION < "3.4"
        expect { params.errors.add(:book, :code, "is invalid") }.to raise_error(
          ArgumentError,
          %(Can't add :book, :code, "is invalid" to {:book=>["is missing"]})
        )
      else
        expect { params.errors.add(:book, :code, "is invalid") }.to raise_error(
          ArgumentError,
          %(Can't add :book, :code, "is invalid" to {book: ["is missing"]})
        )
      end
    end
  end

  describe "inheritance" do
    let(:action) { Class.new(AllowlistedParamsAction).new }

    it "uses the params defined in the parent class" do
      response = action.call(id: 23, unknown: 4, article: {foo: "bar", tags: [:cool]})

      if RUBY_VERSION < "3.4"
        expect(response.body).to eq([%({:id=>23, :article=>{:tags=>[:cool]}})])
      else
        expect(response.body).to eq([%({id: 23, article: {tags: [:cool]}})])
      end
    end
  end
end
