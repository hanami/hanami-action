# frozen_string_literal: true

require "rack/multipart"

module Hanami
  class Action
    module BodyParser
      # Body parser for multipart form data (file uploads).
      #
      # @api private
      module MultipartForm
        def self.call(_body, env)
          # Rack's `parse_multipart` reads the input from the env. We've already rewound this input
          # in BodyParser, before this parser is called.
          ::Rack::Multipart.parse_multipart(env)
        rescue StandardError => exception
          raise BodyParsingError, exception.message
        end
      end
    end
  end
end
