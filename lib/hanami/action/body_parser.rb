# frozen_string_literal: true

require "rack"
require "hanami/utils/hash"

module Hanami
  class Action
    # Parses request bodies based on the action's accepted formats.
    #
    # @api private
    module BodyParser
      FALLBACK_KEY = :_

      class << self
        # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity

        # Parses the request body if applicable
        #
        # @param env [Hash] Rack environment
        # @param config [Hanami::Action::Config] action configuration
        #
        # @return [void]
        def parse(env, config)
          # If the router has already parsed the body, assign it to our own parsed body keys.
          if env.key?(ROUTER_PARSED_BODY)
            env[ACTION_PARSED_BODY] = env[ROUTER_PARSED_BODY]
            env[ACTION_BODY_PARAMS] = env[ROUTER_PARAMS] if env.key?(ROUTER_PARAMS)
            return
          end

          return if env.key?(ACTION_PARSED_BODY)

          input = env[::Rack::RACK_INPUT]
          return unless input

          media_type = Mime.extract_media_type(env["CONTENT_TYPE"])
          return unless media_type

          if config.formats.empty?
            # When no format is explicity configured, parse multipart/form-data bodies as a sensible
            # default. These kinds of form submissions are a standard part of standard web behavior,
            # and users expect them to work out of the box.
            return unless media_type == "multipart/form-data"
          else
            return unless Mime.accepted_content_type?(media_type, config)
          end

          parser = config.formats.body_parser_for(media_type)
          return unless parser

          input = ensure_rewindable_input(env)
          body = read_body(input)
          return if body.nil? || body.empty?

          # Pass both the body string and the Rack env to the parser. Most parsers should only need
          # the body, but the env is there in case access to headers or calling Rack APIs is
          # required.
          parsed = parser.call(body, env)

          # Store the parsed body in Action-specific env keys.
          symbolized = symbolize_body(parsed)
          env[ACTION_PARSED_BODY] = parsed
          env[ACTION_BODY_PARAMS] = symbolized

          # Set Hanami Router keys for backward compatibility.
          env[ROUTER_PARSED_BODY] = parsed
          env[ROUTER_PARAMS] = env.fetch(ROUTER_PARAMS, {}).merge(symbolized)
        end

        # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

        private

        # Ensures the input in the Rack env is rewindable (for Rack 3 compatibility).
        def ensure_rewindable_input(env)
          input = env[::Rack::RACK_INPUT]
          return input if input.respond_to?(:rewind)

          env[::Rack::RACK_INPUT] = ::Rack::RewindableInput.new(input)
        end

        # Reads and rewinds the body.
        def read_body(input)
          input.rewind
          body = input.read
          input.rewind

          body
        end

        # Symbolizes the parsed body, wrapping non-hash values in a fallback key.
        def symbolize_body(parsed)
          if parsed.is_a?(::Hash)
            deep_symbolize(parsed)
          else
            {FALLBACK_KEY => deep_symbolize(parsed)}
          end
        end

        # Recursively symbolizes hash keys within any structure (arrays or hashes).
        def deep_symbolize(value)
          case value
          when ::Hash
            Utils::Hash.deep_symbolize(value)
          when ::Array
            value.map { deep_symbolize(_1) }
          else
            value
          end
        end
      end
    end
  end
end
