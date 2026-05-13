# frozen_string_literal: true

RSpec.describe Hanami::Action do
  describe "#cookies" do
    it "gets cookies" do
      action = GetCookiesAction.new
      response = action.call("HTTP_COOKIE" => "foo=bar")

      expect(response.cookies).to include(foo: "bar")
      expected_headers =
        if Hanami::Action.rack_3?
          {"content-type" => "application/octet-stream; charset=utf-8"}
        else
          {"Content-Length" => "3", "Content-Type" => "application/octet-stream; charset=utf-8"}
        end
      expect(response.headers).to eq(expected_headers)
      expect(response.body).to    eq(["bar"])
    end

    it "change cookies" do
      action = ChangeCookiesAction.new
      response = action.call("HTTP_COOKIE" => "foo=bar")

      expect(response.cookies).to include(foo: "bar")
      expected_headers =
        if Hanami::Action.rack_3?
          {"content-type" => "application/octet-stream; charset=utf-8", "set-cookie" => "foo=baz"}
        else
          {"Content-Length" => "3", "Content-Type" => "application/octet-stream; charset=utf-8", "Set-Cookie" => "foo=baz"}
        end
      expect(response.headers).to eq(expected_headers)
      expect(response.body).to    eq(["bar"])
    end

    it "sets cookies" do
      action = SetCookiesAction.new
      response = action.call({})

      expect(response.body).to eq(["yo"])
      expected_headers =
        if Hanami::Action.rack_3?
          {"content-type" => "application/octet-stream; charset=utf-8", "set-cookie" => "foo=yum%21"}
        else
          {"Content-Length" => "2", "Content-Type" => "application/octet-stream; charset=utf-8", "Set-Cookie" => "foo=yum%21"}
        end
      expect(response.headers).to eq(expected_headers)
    end

    it "sets cookies with options" do
      tomorrow = Time.now + (60 * 60 * 24)
      action   = SetCookiesWithOptionsAction.new(expires: tomorrow)
      response = action.call({})

      expected_headers =
        if Hanami::Action.rack_3?
          {"content-type" => "application/octet-stream; charset=utf-8", "set-cookie" => "kukki=yum%21; domain=hanamirb.org; path=/action; expires=#{tomorrow.httpdate}; secure; httponly"}
        else
          {"Content-Type" => "application/octet-stream; charset=utf-8", "Set-Cookie" => "kukki=yum%21; domain=hanamirb.org; path=/action; expires=#{tomorrow.httpdate}; secure; HttpOnly"}
        end
      expect(response.headers).to eq(expected_headers)
    end

    it "removes cookies" do
      action = RemoveCookiesAction.new
      response = action.call("HTTP_COOKIE" => "foo=bar;rm=me")

      expected_headers =
        if Hanami::Action.rack_3?
          {"content-type" => "application/octet-stream; charset=utf-8", "set-cookie" => "rm=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"}
        else
          {"Content-Type" => "application/octet-stream; charset=utf-8", "Set-Cookie" => "rm=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT"}
        end
      expect(response.headers).to eq(expected_headers)
    end

    it "iterates cookies" do
      action = IterateCookiesAction.new
      response = action.call("HTTP_COOKIE" => "foo=bar;hello=world")

      expect(response.body).to eq(["'foo' has value 'bar', 'hello' has value 'world'"])
    end

    describe "with default cookies" do
      it "gets default cookies" do
        action = GetDefaultCookiesAction.new

        response = action.call({})
        expected_headers =
          if Hanami::Action.rack_3?
            {"content-type" => "application/octet-stream; charset=utf-8", "set-cookie" => "bar=foo; domain=hanamirb.org; path=/action; secure; httponly"}
          else
            {"Content-Length" => "0", "Content-Type" => "application/octet-stream; charset=utf-8", "Set-Cookie" => "bar=foo; domain=hanamirb.org; path=/action; secure; HttpOnly"}
          end
        expect(response.headers).to eq(expected_headers)
      end

      it "overwritten cookies values are respected" do
        action = GetOverwrittenCookiesAction.new

        response = action.call({})
        expected_headers =
          if Hanami::Action.rack_3?
            {"content-type" => "application/octet-stream; charset=utf-8", "set-cookie" => "bar=foo; domain=hanamirb.com; path=/action"}
          else
            {"Content-Length" => "0", "Content-Type" => "application/octet-stream; charset=utf-8", "Set-Cookie" => "bar=foo; domain=hanamirb.com; path=/action"}
          end
        expect(response.headers).to eq(expected_headers)
      end
    end

    describe "with max_age option and without expires option" do
      it "automatically set expires option" do
        now = Time.now
        expect(Time).to receive(:now).at_least(2).and_return(now)

        action = GetAutomaticallyExpiresCookiesAction.new
        response = action.call({})
        max_age = 120
        expect(response.headers["Set-Cookie"]).to include("max-age=#{max_age}")
        expect(response.headers["Set-Cookie"]).to include("expires=#{(Time.now + max_age).httpdate}")
      end
    end
  end
end
