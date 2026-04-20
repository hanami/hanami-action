# frozen_string_literal: true

require_relative "../support/isolation_spec_helper"
require "stringio"

Warning[:deprecated] = true

def capture_stderr
  original = $stderr
  $stderr = StringIO.new
  yield
  $stderr.string
ensure
  $stderr = original
end

controller_warning = capture_stderr { require "hanami/controller" }
hanami_controller_warning = capture_stderr { require "hanami-controller" }

RSpec.describe "hanami-controller deprecations" do
  describe %(require "hanami/controller") do
    it "prints a deprecation warning pointing at hanami/action" do
      expect(controller_warning).to eq(
        "`require \"hanami/controller\"` is deprecated and will be removed in Hanami 3.1. " \
        "Use `require \"hanami/action\"` instead.\n"
      )
    end
  end

  describe %(require "hanami-controller") do
    it "prints a deprecation warning pointing at hanami-action" do
      expect(hanami_controller_warning).to eq(
        "`require \"hanami-controller\"` is deprecated and will be removed in Hanami 3.1. " \
        "Use `require \"hanami-action\"` instead.\n"
      )
    end
  end
end

RSpec::Support::Runner.run
