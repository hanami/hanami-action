# frozen_string_literal: true

module Hanami
  class Action
    # Base class for all Action errors.
    #
    # @api public
    # @since 2.0.0
    class Error < ::StandardError
    end

    # Unknown status HTTP Status error
    #
    # @since 2.0.2
    #
    # @see Hanami::Action::Response#status=
    # @see https://guides.hanamirb.org/v2.0/actions/status-codes/
    class UnknownHttpStatusError < Error
      # @since 2.0.2
      # @api private
      def initialize(code)
        super("unknown HTTP status: `#{code.inspect}'")
      end
    end

    # Unknown format error
    #
    # This error is raised when a action sets a format that it isn't recognized
    # both by `Hanami::Action::Configuration` and the list of Rack mime types
    #
    # @since 2.0.0
    #
    # @see Hanami::Action::Mime#format=
    class UnknownFormatError < Error
      # @since 2.0.0
      # @api private
      def initialize(format)
        message = <<~MSG
          Cannot find a corresponding MIME type for format `#{format.inspect}'.
        MSG

        unless blank?(format)
          message += <<~MSG

            Configure one via: `config.actions.formats.add(:#{format}, "MIME_TYPE_HERE")' in `config/app.rb' to share between actions of a Hanami app.

            Or make it available only in the current action: `config.formats.add(:#{format}, "MIME_TYPE_HERE")'.
          MSG
        end

        super(message)
      end

      private

      def blank?(format)
        format.to_s.match(/\A[[:space:]]*\z/)
      end
    end

    # Error raised when body parsing fails.
    #
    # @api public
    # @since 3.0.0
    class BodyParsingError < Error
    end

    # Error raised when session is accessed but not enabled.
    #
    # This error is raised when `session` or `flash` is accessed/set on request/response objects
    # in actions which do not include `Hanami::Action::Session`.
    #
    # @see Hanami::Action::Session
    # @see Hanami::Action::Request#session
    # @see Hanami::Action::Response#session
    # @see Hanami::Action::Response#flash
    #
    # @api public
    # @since 2.0.0
    class MissingSessionError < Error
      # @api private
      # @since 2.0.0
      def initialize(session_method)
        super(<<~TEXT)
          Sessions are not enabled. To use `#{session_method}`:

          Configure sessions in your Hanami app, e.g.

            module MyApp
              class App < Hanami::App
                # See Rack::Session::Cookie for options
                config.actions.sessions = :cookie, {**cookie_session_options}
              end
            end

          Or include session support directly in your action class:

            include Hanami::Action::Session
        TEXT
      end
    end

    # Invalid CSRF Token
    #
    # @since 0.4.0
    class InvalidCSRFTokenError < Error
    end

    # Error raised when a response is given a body it cannot use.
    #
    # Raised while the action runs, so it can still become a 500.
    #
    # @see Hanami::Action::Response#body=
    # @see Hanami::Action::Response#write
    #
    # @api public
    # @since 3.1.0
    class InvalidBodyError < Error
      # @api private
      # @since 3.1.0
      def initialize(body)
        super(message_for(body))
      end

      private

      def message_for(body)
        if body.is_a?(Stream)
          <<~TEXT
            Cannot write to a response that is streaming.

            `#write' buffers the whole body, which would undo the stream. Send your chunks from
            inside the stream instead:

              response.body = Stream.new { |out| out << "chunk" }
          TEXT
        else
          <<~TEXT
            Cannot use `#{body.class}' as a response body.

            Give a String, or give a `Hanami::Action::Stream' to send the response in chunks:

              response.body = Stream.new { |out| out << "chunk" }
          TEXT
        end
      end
    end

    # Error raised when a stream fails while the web server reads it.
    #
    # The web server reads the stream after the action returns. By then the status and the headers
    # are already sent, so this error cannot become a 500, and the client receives an incomplete
    # response.
    #
    # @see Hanami::Action::Stream#each
    #
    # @api public
    # @since 3.1.0
    class StreamError < Error
    end
  end
end
