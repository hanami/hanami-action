# frozen_string_literal: true

require "hanami/utils/kernel"
require "dry/core"

module Hanami
  class Action
    class Config
      # Action format configuration.
      #
      # @since 2.0.0
      # @api private
      class Formats
        include Dry.Equalizer(:accepted, :mapping)

        # @since 2.0.0
        # @api private
        attr_reader :mapping

        # The array of formats to accept requests by.
        #
        # @example
        #   config.formats.accepted = [:html, :json]
        #   config.formats.accepted # => [:html, :json]
        #
        # @since 2.0.0
        # @api public
        attr_reader :accepted

        # The registered body parsers, as a hash mapping content types to callable parsers.
        #
        # @return [Hash{String => #call}]
        #
        # @since 3.0.0
        # @api public
        attr_reader :body_parsers

        # Returns the default format name.
        #
        # When a request is received that cannot
        #
        # @return [Symbol, nil] the default format name, if any
        #
        # @example
        #   @config.formats.default # => :json
        #
        # @since 2.0.0
        # @api public
        attr_reader :default

        # @since 2.0.0
        # @api private
        def initialize(accepted: [], default: nil, mapping: {})
          @accepted = accepted
          @default = default
          @mapping = mapping
          @body_parsers = {}

          register_default_body_parsers
        end

        # @since 2.0.0
        # @api private
        private def initialize_copy(original)
          super
          @accepted = original.accepted.dup
          @default = original.default
          @mapping = original.mapping.dup
          @body_parsers = original.body_parsers.dup
        end

        # !@attribute [w] accepted
        #   @since 2.3.0
        #   @api public
        def accepted=(formats)
          @accepted = formats.map { |f| Hanami::Utils::Kernel.Symbol(f) }
        end

        # @since 2.3.0
        def accept(*formats)
          self.default = formats.first if default.nil?
          self.accepted = accepted | formats
        end

        # @api private
        def accepted_formats(standard_formats = {})
          accepted.to_h { |format|
            [
              format,
              mapping.fetch(format) { standard_formats[format] }
            ]
          }
        end

        # @since 2.3.0
        def default=(format)
          @default = format.to_sym
        end

        # Registers a format and its associated media types.
        #
        # @param format [Symbol] the format name
        # @param media_type [String] the format's media type
        # @param accept_types [Array<String>] media types to accept in request `Accept` headers
        # @param content_types [Array<String>] media types to accept in request `Content-Type` headers
        #
        # @example
        #   config.formats.register(:scim, media_type: "application/json+scim")
        #
        #   config.formats.register(
        #     :jsonapi,
        #     "application/vnd.api+json",
        #     accept_types: ["application/vnd.api+json", "application/json"],
        #     content_types: ["application/vnd.api+json", "application/json"]
        #   )
        #
        # @return [self]
        #
        # @since 2.3.0
        # @api public
        def register(format, media_type, accept_types: [media_type], content_types: [media_type], parser: nil)
          mapping[format] = Mime::Format.new(
            name: format.to_sym,
            media_type: media_type,
            accept_types: accept_types,
            content_types: content_types
          )

          if parser
            Array(content_types).each do |ct|
              @body_parsers[ct.downcase] = parser
            end
          end

          self
        end

        # @since 2.0.0
        # @api private
        def empty?
          accepted.empty?
        end

        # @since 2.0.0
        # @api private
        def any?
          @accepted.any?
        end

        # @since 2.0.0
        # @api private
        def map(&blk)
          @accepted.map(&blk)
        end

        # Clears any previously added mappings and format values.
        #
        # @return [self]
        #
        # @since 2.0.0
        # @api public
        def clear
          @accepted = []
          @default = nil
          @mapping = {}

          self
        end

        # Returns an array of all accepted media types.
        #
        # @since 2.3.0
        # @api public
        def accept_types
          accepted.map { |format| mapping[format]&.accept_types }.flatten(1).compact
        end

        # Retrieve the format name associated with the given media type
        #
        # @param media_type [String] the media Type
        #
        # @return [Symbol,NilClass] the associated format name, if any
        #
        # @example
        #   @config.formats.format_for("application/json") # => :json
        #
        # @see #mime_type_for
        #
        # @since 2.0.0
        # @api public
        def format_for(media_type)
          mapping.values.reverse.find { |format| format.media_type == media_type }&.name
        end

        # Returns the media type associated with the given format.
        #
        # @param format [Symbol] the format name
        #
        # @return [String, nil] the associated media type, if any
        #
        # @example
        #   @config.formats.media_type_for(:json) # => "application/json"
        #
        # @see #format_for
        #
        # @since 2.3.0
        # @api public
        def media_type_for(format)
          mapping[format]&.media_type
        end

        # @api private
        def accept_types_for(format)
          mapping[format]&.accept_types || []
        end

        # @api private
        def content_types_for(format)
          mapping[format]&.content_types || []
        end

        # @see #media_type_for
        # @since 2.0.0
        # @api public
        alias_method :mime_type_for, :media_type_for

        # @see #media_type_for
        # @since 2.0.0
        # @api public
        alias_method :mime_types_for, :accept_types_for

        # Finds the parser for a content type.
        #
        # @param content_type [String] the content type
        #
        # @return [#call, nil] the parser callable, if registered
        #
        # @api private
        def body_parser_for(content_type)
          @body_parsers[content_type&.downcase]
        end

        private

        def register_default_body_parsers
          # Multipart forms (ordinary urlencoded forms are handled by Rack automatically)
          @body_parsers["multipart/form-data"] = BodyParser::MultipartForm

          # JSON
          @body_parsers["application/json"] = BodyParser::JSON
          @body_parsers["application/vnd.api+json"] = BodyParser::JSON
        end
      end
    end
  end
end
