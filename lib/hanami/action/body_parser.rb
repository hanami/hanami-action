# frozen_string_literal: true

require "rack"

module Hanami
  class Action
    # Parses request bodies based on the action's accepted formats.
    #
    # @api private
    module BodyParser
      FALLBACK_KEY = "_"

      class << self
        # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity

        # Parses the request body if applicable
        #
        # @param env [Hash] Rack environment
        # @param config [Hanami::Action::Config] action configuration
        #
        # @return [void]
        def parse(env, config)
          # If the router has already parsed the body, derive our own keys from it.
          if env.key?(ROUTER_PARSED_BODY)
            parsed = env[ROUTER_PARSED_BODY]
            env[ACTION_PARSED_BODY] = parsed
            env[ACTION_BODY_PARAMS] = body_params(parsed)
            return
          end

          return if env.key?(ACTION_PARSED_BODY)

          input = env[::Rack::RACK_INPUT]
          return unless input

          media_type = Mime.extract_media_type(env[CONTENT_TYPE])
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

          env[ACTION_PARSED_BODY] = parsed
          env[ACTION_BODY_PARAMS] = body_params(parsed)
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

        # Wraps a parsed body into a hash suitable for merging into params.
        #
        # Hash bodies are returned as-is; non-hash bodies (e.g. JSON arrays) are wrapped under
        # {FALLBACK_KEY}. Keys are left as strings. Symbolization happens in {Params}.
        def body_params(parsed)
          parsed.is_a?(::Hash) ? parsed : {FALLBACK_KEY => parsed}
        end
      end
    end
  end
end
