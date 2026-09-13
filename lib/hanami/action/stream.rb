# frozen_string_literal: true

module Hanami
  class Action
    # A lazy response body, for streaming a response instead of buffering it.
    #
    # Assign a stream to {Response#body=} to send a response in chunks. Hanami passes the stream to
    # the web server untouched, so the server writes each chunk as it arrives, and neither Hanami
    # nor the server holds the whole response in memory.
    #
    # A stream takes either a block or an enumerable of chunks. A block receives a writer, which
    # sends a chunk with `#<<` or `#write`. Every chunk must be a `String`, because this is what
    # Rack sends to the client. Turn your own objects into strings before streaming them.
    #
    # An enumerable may hold a resource open, such as a file or a database cursor. If it responds to
    # `#close`, then the stream closes it once the response is sent.
    #
    # By default a streamed response has no `Content-Length` header, and the server sends it with
    # chunked transfer encoding. Give a `length:` if you know the size of the response in bytes.
    #
    # A bare `Stream` resolves inside named action classes, since Ruby looks for constants in the
    # ancestors of the enclosing class.
    #
    # @example Streaming from a block
    #   class Export < Hanami::Action
    #     def handle(request, response)
    #       response.format = :csv
    #       response.body = Stream.new { |out|
    #         records.each_slice(500) do |batch|
    #           out << serialize(batch)
    #         end
    #       }
    #     end
    #   end
    #
    # @example Streaming from an enumerable
    #   response.body = Stream.new(lines)
    #
    # @see Response#body=
    #
    # @since 3.1.0
    # @api public
    class Stream
      # Receives the chunks of a {Stream} block and gives them to the web server.
      #
      # @see Stream#each
      #
      # @since 3.1.0
      # @api private
      class Writer
        def initialize(callback)
          @callback = callback
        end

        # Sends a chunk to the client.
        #
        # @param chunk [String] the chunk to send
        #
        # @return [self] to allow chaining
        #
        # @raise [Hanami::Action::StreamError] if the chunk is not a String
        def <<(chunk)
          unless chunk.is_a?(::String)
            raise StreamError, "Each stream chunk must be a String. Received `#{chunk.class}'."
          end

          @callback.call(chunk)
          self
        end

        alias_method :write, :<<
      end

      # Returns the length of the stream in bytes, or nil if the length is unknown.
      #
      # @return [Integer, nil]
      #
      # @since 3.1.0
      # @api public
      attr_reader :length

      # Returns a new stream.
      #
      # Give either an enumerable of chunks or a block, but not both.
      #
      # @param chunks [#each, nil] an enumerable of String chunks, closed by {#close} if it
      #   responds to `#close`
      # @param length [Integer, nil] the length of the stream in bytes, if known
      # @yieldparam out [Writer] the stream writer, which sends a chunk with `#<<` or `#write`
      #
      # @raise [ArgumentError] if given both an enumerable and a block, or neither
      #
      # @since 3.1.0
      # @api public
      def initialize(chunks = nil, length: nil, &block)
        unless chunks.nil? ^ block.nil?
          raise ArgumentError, "give #{self.class} either an enumerable of chunks or a block"
        end

        @chunks = chunks
        @block = block
        @length = length
        @closed = false
      end

      # Yields each chunk of the stream.
      #
      # The web server calls this method. It runs after the action returns, so the status and the
      # headers of the response are already sent by the time the chunks are built.
      #
      # @yieldparam chunk [String]
      #
      # @return [Enumerator] if no block is given
      #
      # @raise [Hanami::Action::StreamError] if the stream is closed, or if a chunk is not a String
      #
      # @since 3.1.0
      # @api public
      def each(&callback)
        return to_enum(:each) if callback.nil?

        if @closed
          raise StreamError, "This stream is closed. A response body can be sent only once."
        end

        writer = Writer.new(callback)

        if @block
          @block.call(writer)
        else
          @chunks.each { |chunk| writer << chunk }
        end

        self
      end

      # Closes the stream and its source, releasing whatever it holds open.
      #
      # The web server calls this method after it sends the last chunk. Hanami also calls it when it
      # replaces the body of the response before the server sees it, such as for a HEAD request or
      # when the action halts.
      #
      # @return [void]
      #
      # @since 3.1.0
      # @api public
      def close
        return if @closed

        @closed = true
        @chunks.close if @chunks.respond_to?(:close)
      end

      # Returns true if the stream is closed.
      #
      # @return [Boolean]
      #
      # @since 3.1.0
      # @api public
      def closed?
        @closed
      end

      # Returns false.
      #
      # A stream always counts as a body, even before anything reads it, so that
      # {Response#renderable?} and {Response#allow_redirect?} treat it as one.
      #
      # @return [false]
      #
      # @since 3.1.0
      # @api private
      def empty?
        false
      end
    end
  end
end
