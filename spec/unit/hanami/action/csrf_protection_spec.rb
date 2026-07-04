# frozen_string_literal: true

RSpec.describe Hanami::Action::CSRFProtection do
  subject(:action) {
    Class.new(Hanami::Action) {
      include Hanami::Action::CSRFProtection
    }.new
  }

  let(:response) { action.(request) }

  describe "Requests requiring protection (Non-idempotent request methods)" do
    let(:request) { {"REQUEST_METHOD" => "POST"} }

    context "No existing session" do
      let(:request) { super().merge("rack.session" => {}) }

      context "non-matching CSRF token in request param" do
        let(:request) { super().merge(_csrf_token: "non-matching") }

        it "rejects the request" do
          expect { response }.to raise_error Hanami::Action::InvalidCSRFTokenError
        end
      end

      context "non-matching CSRF token in request header" do
        let(:request) { super().merge("HTTP_X_CSRF_TOKEN" => "non-matching") }

        it "rejects the request" do
          expect { response }.to raise_error Hanami::Action::InvalidCSRFTokenError
        end
      end

      context "missing CSRF token in request" do
        it "rejects the request" do
          expect { response }.to raise_error Hanami::Action::InvalidCSRFTokenError
        end
      end
    end

    context "Existing session" do
      let(:request) { super().merge("rack.session" => session) }
      let(:session) { {_csrf_token: session_token} }
      let(:session_token) { "abc123" }

      context "matching CSRF token in request" do
        let(:request) { super().merge("_csrf_token" => session_token) }

        it "accepts the request" do
          expect(response.status).to eq 200
        end
      end

      context "matching CSRF token in request header" do
        let(:request) { super().merge("HTTP_X_CSRF_TOKEN" => session_token) }

        it "accepts the request" do
          expect(response.status).to eq 200
        end
      end

      context "non-matching CSRF token in request param" do
        let(:request) { super().merge(_csrf_token: "non-matching") }

        it "rejects the request" do
          expect { response }.to raise_error Hanami::Action::InvalidCSRFTokenError
        end
      end

      context "non-matching CSRF token in request header" do
        let(:request) { super().merge("HTTP_X_CSRF_TOKEN" => "non-matching") }

        it "rejects the request" do
          expect { response }.to raise_error Hanami::Action::InvalidCSRFTokenError
        end
      end

      context "missing CSRF token in request" do
        it "rejects the request" do
          expect { response }.to raise_error Hanami::Action::InvalidCSRFTokenError
        end
      end

      context "CSRF checks skipped" do
        subject(:action) {
          Class.new(Hanami::Action) {
            include Hanami::Action::CSRFProtection

            def verify_csrf_token?(_req, _res)
              false
            end
          }.new
        }

        context "missing CSRF token in request" do
          it "accepts the request" do
            expect(response.status).to eq 200
          end
        end

        context "non-matching CSRF token in request param" do
          let(:request) { super().merge(_csrf_token: "non-matching") }

          it "accepts the request" do
            expect(response.status).to eq 200
          end
        end

        context "non-matching CSRF token in request header" do
          let(:request) { super().merge("HTTP_X_CSRF_TOKEN" => "non-matching") }

          it "accepts the request" do
            expect(response.status).to eq 200
          end
        end
      end
    end
  end

  context "Requests not requiring protection (Idempotent request methods)" do
    %w[GET HEAD TRACE OPTIONS].each do |request_method|
      describe request_method do
        let(:request) { {"REQUEST_METHOD" => request_method} }

        context "No existing session" do
          it "sets a CSRF token in the response session" do
            expect(response.session[:_csrf_token]).to be_a_kind_of String
          end
        end

        context "Existing session" do
          let(:request) { super().merge("rack.session" => session) }
          let(:session) { {_csrf_token: session_token} }
          let(:session_token) { "abc123" }

          it "includes the existing CSRF token in the response session" do
            expect(response.session[:_csrf_token]).to eq session_token
          end
        end
      end
    end
  end
end
