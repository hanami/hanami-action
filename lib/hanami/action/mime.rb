# frozen_string_literal: true

require "hanami/utils"
require "rack/utils"
require "rack/mime"
require_relative "errors"

module Hanami
  class Action
    # @api private
    module Mime
      # Most commom media types used for responses
      #
      # @since 1.0.0
      # @api public
      TYPES = {
        atom: "application/atom+xml",
        avi: "video/x-msvideo",
        bmp: "image/bmp",
        bz2: "application/x-bzip2",
        bz: "application/x-bzip",
        chm: "application/vnd.ms-htmlhelp",
        css: "text/css",
        csv: "text/csv",
        flv: "video/x-flv",
        form: "application/x-www-form-urlencoded",
        gif: "image/gif",
        gz: "application/x-gzip",
        h264: "video/h264",
        html: "text/html",
        ico: "image/vnd.microsoft.icon",
        ics: "text/calendar",
        jpg: "image/jpeg",
        js: "application/javascript",
        json: "application/json",
        manifest: "text/cache-manifest",
        mov: "video/quicktime",
        mp3: "audio/mpeg",
        mp4: "video/mp4",
        mp4a: "audio/mp4",
        mpg: "video/mpeg",
        multipart: "multipart/form-data",
        oga: "audio/ogg",
        ogg: "application/ogg",
        ogv: "video/ogg",
        pdf: "application/pdf",
        pgp: "application/pgp-encrypted",
        png: "image/png",
        psd: "image/vnd.adobe.photoshop",
        rss: "application/rss+xml",
        rtf: "application/rtf",
        sh: "application/x-sh",
        svg: "image/svg+xml",
        swf: "application/x-shockwave-flash",
        tar: "application/x-tar",
        torrent: "application/x-bittorrent",
        tsv: "text/tab-separated-values",
        txt: "text/plain",
        uri: "text/uri-list",
        vcs: "text/x-vcalendar",
        wav: "audio/x-wav",
        webm: "video/webm",
        wmv: "video/x-ms-wmv",
        woff2: "application/font-woff2",
        woff: "application/font-woff",
        wsdl: "application/wsdl+xml",
        xhtml: "application/xhtml+xml",
        xml: "application/xml",
        xslt: "application/xslt+xml",
        yml: "text/yaml",
        zip: "application/zip"
      }.freeze

      # @api private
      ANY_TYPE = "*/*"

      # @api private
      Format = Data.define(:name, :media_type, :accept_types, :content_types) do
        def initialize(name:, media_type:, accept_types: [media_type], content_types: [media_type])
          super
        end
      end

      # @api private
      FORMATS = TYPES
        .to_h { |name, media_type| [name, Format.new(name:, media_type:)] }
        .update(
          all: Format.new(
            name: :all,
            media_type: "application/octet-stream",
            accept_types: ["*/*"],
            content_types: ["*/*"]
          ),
          html: Format.new(
            name: :html,
            media_type: "text/html",
            content_types: ["application/x-www-form-urlencoded", "multipart/form-data"]
          )
        )
        .freeze
      private_constant :FORMATS

      # @api private
      MEDIA_TYPES_TO_FORMATS = FORMATS.each_with_object({}) { |(_name, format), hsh|
        hsh[format.media_type] = format
      }.freeze
      private_constant :MEDIA_TYPES_TO_FORMATS

      # @api private
      ACCEPT_TYPES_TO_FORMATS = FORMATS.each_with_object({}) { |(_name, format), hsh|
        format.accept_types.each { |type| hsh[type] = format }
      }.freeze
      private_constant :ACCEPT_TYPES_TO_FORMATS

      class << self
        # Yields if an action is configured with `formats`, the request has an `Accept` header, and
        # none of the Accept types matches the accepted formats. The given block is expected to halt
        # the request handling.
        #
        # If any of these conditions are not met, then the request is acceptable and the method
        # returns without yielding.
        #
        # @see Action#enforce_accepted_media_types
        # @see Config#formats
        #
        # @api private
        def enforce_accept(request, config)
          return unless request.accept_header?

          accept_types = ::Rack::Utils.q_values(request.accept).map(&:first)
          return if accept_types.any? { |type| accepted_type?(type, config) }

          yield
        end

        # Yields if an action is configured with `formats`, the request has a `Content-Type` header,
        # and the content type does not match the accepted formats. The given block is expected to
        # halt the request handling.
        #
        # If any of these conditions are not met, then the request is acceptable and the method
        # returns without yielding.
        #
        # @see Action#enforce_accepted_media_types
        # @see Config#formats
        #
        # @api private
        def enforce_content_type(request, config)
          # Compare media type (without parameters) instead of full Content-Type header to avoid
          # false negatives (e.g., multipart/form-data; boundary=...)
          media_type = request.media_type

          return if media_type.nil?

          return if accepted_content_type?(media_type, config)

          yield
        end

        # Returns a string combining a media type and charset, intended for setting as the
        # `Content-Type` header for the response to the given request.
        #
        # This uses the request's `Accept` header (if present) along with the configured formats to
        # determine the best content type to return.
        #
        # @return [String]
        #
        # @see Action#call
        #
        # @api private
        def response_content_type_with_charset(request, config)
          content_type_with_charset(
            response_content_type(request, config),
            config.default_charset || Action::DEFAULT_CHARSET
          )
        end

        # Returns the default response Content-Type (with charset) for a request without a usable
        # `Accept` header. This depends only on config, so an action can compute it once and reuse
        # it across requests instead of recomputing per call.
        #
        # @return [String]
        #
        # @see Action#call
        #
        # @since x.x.x
        # @api private
        def default_response_content_type_with_charset(config)
          content_type_with_charset(
            default_response_content_type(config),
            config.default_charset || Action::DEFAULT_CHARSET
          )
        end

        # Returns a format name for the given content type.
        #
        # The format name will come from the configured formats, if such a format is configured
        # there, or instead from the default list of formats in `Mime::TYPES`.
        #
        # Returns nil if no matching format can be found.
        #
        # This is used to return the format name a {Response}.
        #
        # @example
        #   format_from_media_type("application/json;charset=utf-8", config) # => :json
        #
        # @return [Symbol, nil]
        #
        # @see Response#format
        # @see Action#finish
        #
        # @api private
        def format_from_media_type(media_type, config)
          return if media_type.nil?

          mt = extract_media_type(media_type)
          config.formats.format_for(mt) || MEDIA_TYPES_TO_FORMATS[mt]&.name
        end

        # Returns a format name and content type pair for a given format name or content type
        # string.
        #
        # @example
        #   format_and_media_type(:json, config)
        #   # => [:json, "application/json"]
        #
        #   format_and_media_type("application/json", config)
        #   # => [:json, "application/json"]
        #
        # @example Unknown format name
        #   format_and_media_type(:unknown, config)
        #   # raises Hanami::Action::UnknownFormatError
        #
        # @example Unknown content type
        #   format_and_media_type("application/unknown", config)
        #   # => [nil, "application/unknown"]
        #
        # @return [Array<(Symbol, String)>]
        #
        # @raise [Hanami::Action::UnknownFormatError] if an unknown format name is given
        #
        # @api private
        def format_and_media_type(value, config)
          case value
          when Symbol
            [value, format_to_media_type(value, config)]
          when String
            [format_from_media_type(value, config), value]
          else
            raise UnknownFormatError.new(value)
          end
        end

        # Returns a string combining the given content type and charset, intended for setting as a
        # `Content-Type` header.
        #
        # @example
        #   Mime.content_type_with_charset("application/json", "utf-8")
        #   # => "application/json; charset=utf-8"
        #
        # @param content_type [String]
        # @param charset [String]
        #
        # @return [String]
        #
        # @api private
        def content_type_with_charset(content_type, charset)
          "#{content_type}; charset=#{charset}"
        end

        # Extracts the media type from a Content-Type header value, removing parameters
        # like charset, boundary, etc.
        #
        # @param content_type [String, nil] the Content-Type header value
        # @return [String, nil] the media type without parameters, downcased
        #
        # @example
        #   extract_media_type("application/json; charset=utf-8")
        #   # => "application/json"
        #
        #   extract_media_type("multipart/form-data; boundary=----WebKitFormBoundary")
        #   # => "multipart/form-data"
        #
        # @api private
        def extract_media_type(content_type)
          return nil if content_type.nil? || content_type.empty?

          # Strip charset, boundary, and other parameters (separated by semicolon)
          content_type.split(";", 2).first.strip.downcase
        end

        # Patched version of <tt>Rack::Utils.best_q_match</tt>.
        #
        # @api private
        #
        # @see http://www.rubydoc.info/gems/rack/Rack/Utils#best_q_match-class_method
        # @see https://github.com/rack/rack/pull/659
        # @see https://github.com/hanami/hanami-action/issues/59
        # @see https://github.com/hanami/hanami-action/issues/104
        # @see https://github.com/hanami/hanami-action/issues/275
        def best_q_match(q_value_header, available_mimes)
          ::Rack::Utils.q_values(q_value_header).each_with_index.map { |(req_mime, quality), index|
            match = available_mimes.find { |am| ::Rack::Mime.match?(am, req_mime) }
            next unless match

            RequestMimeWeight.new(req_mime, quality, index, match)
          }.compact.max&.format
        end

        # Checks if a content type is acceptable for the configured formats.
        #
        # @param content_type [String] the media type to check
        # @param config [Hanami::Action::Config] action configuration
        # @return [Boolean] true if acceptable
        #
        # @api private
        def accepted_content_type?(content_type, config)
          accepted_content_types(config).any? { |accepted_content_type|
            ::Rack::Mime.match?(content_type, accepted_content_type)
          }
        end

        private

        # @api private
        def accepted_type?(media_type, config)
          accepted_types(config).any? { |accepted_type|
            ::Rack::Mime.match?(media_type, accepted_type)
          }
        end

        # @api private
        def accepted_types(config)
          return [ANY_TYPE] if config.formats.empty?

          config.formats.map { |format| format_to_accept_types(format, config) }.flatten(1)
        end

        def format_to_accept_types(format, config)
          configured_types = config.formats.accept_types_for(format)
          return configured_types if configured_types.any?

          FORMATS
            .fetch(format) { raise Hanami::Action::UnknownFormatError.new(format) }
            .accept_types
        end

        # @api private
        def accepted_content_types(config)
          return [ANY_TYPE] if config.formats.empty?

          config.formats.map { |format| format_to_content_types(format, config) }.flatten(1)
        end

        # @api private
        def format_to_content_types(format, config)
          configured_types = config.formats.content_types_for(format)
          return configured_types if configured_types.any?

          FORMATS
            .fetch(format) { raise Hanami::Action::UnknownFormatError.new(format) }
            .content_types
        end

        # @api private
        def response_content_type(request, config)
          # This method prepares the default `Content-Type` for the response. Importantly, it only
          # does this after `#enforce_accept` and `#enforce_content_type` have already passed the
          # request. So by the time we get here, the request has been deemed acceptable to the
          # action, so we can try to be as helpful as possible in setting an appropriate content
          # type for the response.

          if request.accept_header?
            content_type =
              if config.formats.empty? || config.formats.accepted.include?(:all)
                permissive_response_content_type(request, config)
              else
                restrictive_response_content_type(request, config)
              end

            return content_type if content_type
          end

          default_response_content_type(config)
        end

        # Returns the response media type for a request without a usable `Accept` header: the
        # configured default format's media type, or the global default content type.
        #
        # @api private
        def default_response_content_type(config)
          if config.formats.default
            format_to_media_type(config.formats.default, config)
          else
            Action::DEFAULT_CONTENT_TYPE
          end
        end

        # @api private
        def permissive_response_content_type(request, config)
          # If no accepted formats are configured, or if the formats include :all, then we're
          # working with a "permissive" action. In this case we simply want a response content type
          # that corresponds to the request's accept header as closely as possible. This means we
          # work from _all_ the media types we know of.

          all_media_types =
            (ACCEPT_TYPES_TO_FORMATS.keys | MEDIA_TYPES_TO_FORMATS.keys) +
            config.formats.accept_types

          best_q_match(request.accept, all_media_types)
        end

        # @api private
        def restrictive_response_content_type(request, config)
          # When specific formats are configured, this is a "resitrctive" action. Here we want to
          # match against the configured accept types only, and work back from those to the
          # configured format, so we can use its canonical media type for the content type.

          accept_types_to_formats = config.formats.accepted_formats(FORMATS)
            .each_with_object({}) { |(_, format), hsh|
              format.accept_types.each { hsh[_1] = format }
            }

          accept_type = best_q_match(request.accept, accept_types_to_formats.keys)
          accept_types_to_formats[accept_type].media_type if accept_type
        end

        # @api private
        def format_to_media_type(format, config)
          configured_type = config.formats.media_type_for(format)
          return configured_type if configured_type

          FORMATS
            .fetch(format) { raise Hanami::Action::UnknownFormatError.new(format) }
            .media_type
        end
      end
    end
  end
end
