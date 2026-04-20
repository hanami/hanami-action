# frozen_string_literal: true

require_relative "hanami/action"

warn(
  "`require \"hanami-controller\"` is deprecated and will be removed in Hanami 3.1. " \
  "Use `require \"hanami-action\"` instead.",
  category: :deprecated
)
