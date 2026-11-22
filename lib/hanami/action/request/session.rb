# frozen_string_literal: true

require "forwardable"

module Hanami
  class Action
    class Request < ::Rack::Request
      # Wrapper for Rack-provided sessions, allowing access using symbol keys.
      #
      # @since 2.3.0
      # @api public
      class Session
        extend Forwardable

        def_delegators \
          :@session,
          :[],
          :[]=,
          :key?,
          :clear,
          :delete,
          :empty?,
          :size,
          :length,
          :each,
          :to_h,
          :inspect,
          :keys,
          :values

        def initialize(session)
          @session = session
        end

        alias_method :has_key?, :key?
        alias_method :include?, :key?

        def ==(other)
          Utils::Hash.deep_symbolize(@session) == Utils::Hash.deep_symbolize(other)
        end

        private

        # Provides a fallback for any methods not handled by the def_delegators.
        def method_missing(method_name, *args, &block)
          if @session.respond_to?(method_name)
            @session.send(method_name, *args, &block)
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          @session.respond_to?(method_name, include_private) || super
        end
      end
    end
  end
end
