# frozen_string_literal: true

require "hanami/action"

# Hanami
#
# @since 0.1.0
module Hanami
  # A set of logically grouped actions
  #
  # @see Hanami::Action
  #
  # @since 0.1.0
  # @api public
  module Controller
  end
end

warn(
  "`require \"hanami/controller\"` is deprecated and will be removed in Hanami 3.1. " \
  "Use `require \"hanami/action\"` instead.",
  category: :deprecated
)
