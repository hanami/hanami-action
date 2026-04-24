# frozen_string_literal: true

require "rack"
require "json"

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
      end

      context "with Hanami::Router" do
        it "returns all the params as they are" do
          # Hanami::Router params are always symbolized
          response = action.call("router.params" => {id: "23"})

          if RUBY_VERSION < "3.4"
            expect(response.body).to eq([%({:id=>"23"})])
          else
            expect(response.body).to eq([%({id: "23"})])
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

        context "with Hanami::Router" do
          it "returns only the listed params" do
            response = action.call("router.params" => {id: 23, another: "x"})

            if RUBY_VERSION < "3.4"
              expect(response.body).to eq([%({:id=>23})])
            else
              expect(response.body).to eq([%({id: 23})])
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

        context "with Hanami::Router" do
          it "returns only the listed params" do
            response = action.call("router.params" => {username: "jodosha", y: "x"})

            if RUBY_VERSION < "3.4"
              expect(response.body).to eq([%({:username=>"jodosha"})])
            else
              expect(response.body).to eq([%({username: "jodosha"})])
            end
          end
        end
      end
    end
  end

  describe "validations" do
    it "isn't valid with empty params" do
      params = TestParams.new(env: {})

      expect(params.valid?).to be(false)

      expect(params.errors.fetch(:email)).to   eq(["is missing"])
      expect(params.errors.fetch(:name)).to    eq(["is missing"])
      expect(params.errors.fetch(:tos)).to     eq(["is missing"])
      expect(params.errors.fetch(:address)).to eq(["is missing"])

      expect(params.error_messages).to eq(["Email is missing", "Name is missing", "Tos is missing", "Age is missing", "Address is missing"])
    end

    it "isn't valid with empty nested params" do
      params = NestedParams.new(env: {signup: {}})

      expect(params.valid?).to be(false)

      expect(params.errors.fetch(:signup).fetch(:name)).to eq(["is missing"])

      expect(params.error_messages).to eq(["Name is missing", "Age is missing"])
    end

    it "is it valid when all the validation criteria are met" do
      params = TestParams.new(
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
      params = TestParams.new(env: {name: "John", age: "1", address: {line_one: "10 High Street"}})

      expect(params[:name]).to               eq("John")
      expect(params[:age]).to                be(1)
      expect(params[:address][:line_one]).to eq("10 High Street")
    end

    it "allows nested hash access via symbols" do
      params = TestParams.new(env: {name: "John", address: {line_one: "10 High Street", deep: {deep_attr: 1}}})
      expect(params[:name]).to                       eq("John")
      expect(params[:address][:line_one]).to         eq("10 High Street")
      expect(params[:address][:deep][:deep_attr]).to be(1)
    end
  end

  describe "#get" do
    context "with data" do
      let(:params) do
        TestParams.new(
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
      let(:params) { TestParams.new(env: {}) }

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
    let(:params) { TestParams.new(env: {name: "Jane"}) }

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

      actual = TestParams.new(env: input).to_h
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

        actual = TestParams.new(env: input).to_h
        expect(actual).to eq(expected)

        expect(actual).to                  be_kind_of(::Hash)
        expect(actual[:address]).to        be_kind_of(::Hash)
        expect(actual[:address][:deep]).to be_kind_of(::Hash)
      end
    end
  end

  describe "#to_hash" do
    let(:params) { TestParams.new(env: {name: "Jane"}) }

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

      actual = TestParams.new(env: input).to_hash
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

        actual = TestParams.new(env: input).to_hash
        expect(actual).to eq(expected)

        expect(actual).to                  be_kind_of(::Hash)
        expect(actual[:address]).to        be_kind_of(::Hash)
        expect(actual[:address][:deep]).to be_kind_of(::Hash)
      end

      it "does not stringify values" do
        input  = {"name" => 123}
        params = TestParams.new(env: input)

        expect(params[:name]).to be(123)
      end
    end
  end

  describe "#deconstruct_keys" do
    let(:params) do
      TestParams.new(
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
    let(:klass) do
      Class.new(described_class) do
        params do
          required(:book).schema do
            required(:code).filled(:str?)
          end
        end
      end
    end

    let(:params) { klass.new(env: {book: {code: "abc"}}) }

    it "returns Hanami::Action::Params::Errors" do
      expect(params.errors).to be_kind_of(Hanami::Action::Params::Errors)
    end

    it "alters the returning value of #valid?" do
      expect(params).to be_valid

      params.errors.add(:book, :code, "is not unique")
      expect(params).to_not be_valid
    end

    it "appends message to already existing messages" do
      params = klass.new(env: {book: {}})
      params.errors.add(:book, :code, "is invalid")

      expect(params.error_messages).to eq(["Code is missing", "Code is invalid"])
    end

    it "gets listed in #error_messages" do
      params.errors.add(:book, :code, "is not unique")
      expect(params.error_messages).to eq(["Code is not unique"])
    end

    it "raises error when try to add an error " do
      params = klass.new(env: {})

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

  describe "JSON body with route params" do
    subject(:action) do
      Class.new(Hanami::Action) do
        config.formats.accept :json

        def handle(req, res)
          res.body = req.params.to_h.inspect
        end
      end.new
    end

    # Simulates the action parsing the JSON body itself (standalone use, no router body parsing).
    def action_parsed_env(route_params:, body:)
      Rack::MockRequest.env_for(
        "/",
        method: "POST",
        input: JSON.generate(body),
        "CONTENT_TYPE" => "application/json",
        "router.params" => route_params,
      )
    end

    # Simulates what hanami-router does: parse the JSON body and merge everything
    # into router.params before handing off to the action.
    def router_parsed_env(route_params:, body:)
      raw_json = JSON.generate(body)
      parsed = JSON.parse(raw_json)
      symbolized = JSON.parse(raw_json, symbolize_names: true)

      Rack::MockRequest.env_for(
        "/",
        method: "POST",
        input: raw_json,
        "CONTENT_TYPE" => "application/json",
        "router.params" => route_params.merge(symbolized),
        "router.parsed_body" => parsed,
      )
    end

    context "when the action parses the JSON body (standalone, no router body parsing)" do
      it "includes route params alongside JSON body params" do
        env = action_parsed_env(route_params: {slug: "my-article"}, body: {comment: {body: "hello"}})
        response = action.call(env)

        expect(response[:params][:slug]).to eq("my-article")
        expect(response[:params][:comment]).to eq({body: "hello"})
      end

      it "includes route params when there is no body" do
        env = Rack::MockRequest.env_for(
          "/",
          method: "POST",
          "CONTENT_TYPE" => "application/json",
          "router.params" => {slug: "my-article"},
        )
        response = action.call(env)

        expect(response[:params][:slug]).to eq("my-article")
      end
    end

    context "when the router pre-parses the JSON body" do
      it "includes route params alongside JSON body params" do
        env = router_parsed_env(route_params: {slug: "my-article"}, body: {comment: {body: "hello"}})
        response = action.call(env)

        expect(response[:params][:slug]).to eq("my-article")
        expect(response[:params][:comment]).to eq({body: "hello"})
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
