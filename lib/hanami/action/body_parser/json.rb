# frozen_string_literal: true

require "json"

module Hanami
  class Action
    module BodyParser
      # Body parser for JSON request bodies.
      #
      # @api private
      module JSON
        def self.call(body, _env)
          ::JSON.parse(body)
        rescue ::JSON::ParserError => exception
          raise BodyParsingError, exception.message
        end
      end
    end
  end
end
