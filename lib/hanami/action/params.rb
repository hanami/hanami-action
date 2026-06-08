# frozen_string_literal: true

require "rack/request"
require "hanami/utils/hash"

module Hanami
  class Action
    # Provides access to params included in a Rack request.
    #
    # Offers useful access to params via methods like {#[]}, {#get} and {#to_h}.
    #
    # These params are available via {Request#params}.
    #
    # This class is used by default when {Hanami::Action::Validatable} is not included, or when no
    # {Validatable::ClassMethods#params params} validation schema is defined.
    #
    # @see Hanami::Action::Request#params

    # A set of params requested by the client.
    #
    # Extracts the relevant params from a Rack env (query string, request body, and route params
    # placed in `env["router.params"]` by the router), or from a plain hash passed for convenience
    # in tests.
    #
    # @since 0.1.0
    class Params
      # @since x.x.x
      # @api private
      EMPTY_PARAMS = {}.freeze

      # Params errors
      #
      # @since 1.1.0
      class Errors < SimpleDelegator
        # @since 1.1.0
        # @api private
        def initialize(errors = {})
          super(errors.dup)
        end

        # Add an error to the param validations
        #
        # This has a semantic similar to `Hash#dig` where you use a set of keys
        # to get a nested value, here you use a set of keys to set a nested
        # value.
        #
        # @param args [Array<Symbol, String>] an array of arguments: the last
        #   one is the message to add (String), while the beginning of the array
        #   is made of keys to reach the attribute.
        #
        # @raise [ArgumentError] when try to add a message for a key that is
        #   already filled with incompatible message type.
        #   This usually happens with nested attributes: if you have a `:book`
        #   schema and the input doesn't include data for `:book`, the messages
        #   will be `["is missing"]`. In that case you can't add an error for a
        #   key nested under `:book`.
        #
        # @since 1.1.0
        #
        # @example Basic usage
        #   require "hanami/action"
        #
        #   class MyAction < Hanami::Action
        #     params do
        #       required(:book).schema do
        #         required(:isbn).filled(:str?)
        #       end
        #     end
        #
        #     def handle(request, response)
        #       # 1. Don't try to save the record if the params aren't valid
        #       return unless request.params.valid?
        #
        #       BookRepository.new.create(request.params[:book])
        #     rescue Hanami::Model::UniqueConstraintViolationError
        #       # 2. Add an error in case the record wasn't unique
        #       request.params.errors.add(:book, :isbn, "is not unique")
        #     end
        #   end
        #
        # @example Invalid argument
        #   require "hanami/action"
        #
        #   class MyAction < Hanami::Action
        #     params do
        #       required(:book).schema do
        #         required(:title).filled(:str?)
        #       end
        #     end
        #
        #     def handle(request, *)
        #       puts request.params.to_h   # => {}
        #       puts request.params.valid? # => false
        #       puts request.params.error_messages # => ["Book is missing"]
        #       puts request.params.errors         # => {:book=>["is missing"]}
        #
        #       request.params.errors.add(:book, :isbn, "is not unique") # => ArgumentError
        #     end
        #   end
        def add(*args)
          *keys, key, error = args
          _nested_attribute(keys, key) << error
        rescue TypeError
          raise ArgumentError.new("Can't add #{args.map(&:inspect).join(', ')} to #{inspect}")
        end

        private

        # @since 1.1.0
        # @api private
        def _nested_attribute(keys, key)
          if keys.empty?
            self
          else
            keys.inject(self) { |result, k| result[k] ||= {} }
            dig(*keys)
          end[key] ||= []
        end
      end

      # @attr_reader env [Hash] the Rack env
      #
      # @since 0.7.0
      # @api private
      attr_reader :env

      # @attr_reader raw [Hash] the raw params from the request
      #
      # @since 0.7.0
      # @api private
      attr_reader :raw

      # Returns structured error messages
      #
      # @return [Hash]
      #
      # @since 0.7.0
      #
      # @example
      #   params.errors
      #     # => {
      #            :email=>["is missing", "is in invalid format"],
      #            :name=>["is missing"],
      #            :tos=>["is missing"],
      #            :age=>["is missing"],
      #            :address=>["is missing"]
      #          }
      attr_reader :errors

      # Initialize the params and freeze them.
      #
      # @param env [Hash] a Rack env or an hash of params.
      #
      # @return [Params]
      #
      # @since 0.1.0
      # @api private
      def initialize(env:, contract: nil)
        @env = env
        @raw = _extract_params

        if contract
          validation = contract.call(raw)
          @params = validation.to_h
          @errors = Errors.new(validation.errors.to_h)
        else
          # No contract configured: permit all params with symbolized keys, skipping
          # `deep_symbolize` when there's nothing to do.
          @params = raw.empty? ? EMPTY_PARAMS : Utils::Hash.deep_symbolize(raw)
          @errors = Errors.new
        end

        freeze
      end

      # Returns the value for the given params key.
      #
      # @param key [Symbol] the key
      #
      # @return [Object,nil] the associated value, if found
      #
      # @since 0.7.0
      # @api public
      def [](key)
        @params[key]
      end

      # Returns an value associated with the given params key.
      #
      # You can access nested attributes by listing all the keys in the path. This uses the same key
      # path semantics as `Hash#dig`.
      #
      # @param keys [Array<Symbol,Integer>] the key
      #
      # @return [Object,NilClass] return the associated value, if found
      #
      # @example
      #   require "hanami/action"
      #
      #   module Deliveries
      #     class Create < Hanami::Action
      #       def handle(request, *)
      #         request.params.get(:customer_name)     # => "Luca"
      #         request.params.get(:uknown)            # => nil
      #
      #         request.params.get(:address, :city)    # => "Rome"
      #         request.params.get(:address, :unknown) # => nil
      #
      #         request.params.get(:tags, 0)           # => "foo"
      #         request.params.get(:tags, 1)           # => "bar"
      #         request.params.get(:tags, 999)         # => nil
      #
      #         request.params.get(nil)                # => nil
      #       end
      #     end
      #   end
      #
      # @since 0.7.0
      # @api public
      def get(*keys)
        @params.dig(*keys)
      end

      # This is for compatibility with Hanami::Helpers::FormHelper::Values
      #
      # @api private
      # @since 0.8.0
      alias_method :dig, :get

      # Returns flat collection of full error messages
      #
      # @return [Array]
      #
      # @since 0.7.0
      #
      # @example
      #   params.error_messages
      #     # => [
      #            "Email is missing",
      #            "Email is in invalid format",
      #            "Name is missing",
      #            "Tos is missing",
      #            "Age is missing",
      #            "Address is missing"
      #          ]
      def error_messages(error_set = errors)
        error_set.each_with_object([]) do |(key, messages), result|
          k = Utils::String.titleize(key)

          msgs = if messages.is_a?(::Hash)
                   error_messages(messages)
                 else
                   messages.map { |message| "#{k} #{message}" }
                 end

          result.concat(msgs)
        end
      end

      # Returns true if no validation errors are found,
      # false otherwise.
      #
      # @return [TrueClass, FalseClass]
      #
      # @since 0.7.0
      #
      # @example
      #   params.valid? # => true
      def valid?
        errors.empty?
      end

      # Iterates over the params.
      #
      # Calls the given block with each param key-value pair; returns the full hash of params.
      #
      # @yieldparam key [Symbol]
      # @yieldparam value [Object]
      #
      # @return [to_h]
      #
      # @since 0.7.1
      # @api public
      def each(&blk)
        to_h.each(&blk)
      end

      # Serialize validated params to Hash
      #
      # @return [::Hash]
      #
      # @since 0.3.0
      def to_h
        @params
      end
      alias_method :to_hash, :to_h

      # Pattern-matching support
      #
      # @return [::Hash]
      #
      # @since 2.0.2
      def deconstruct_keys(*)
        to_hash
      end

      private

      def _extract_params # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        # Without PATH_INFO (URL path from a server) or rack.input (request body), env has no
        # Rack-sourced data for us to parse as params; it's likely a bare hash passed to
        # `Action#call` for convenience in tests. In this case, treat the env itself as the params.
        return env unless env.key?(PATH_INFO) || env.key?(RACK_INPUT)

        query_string = env[::Rack::QUERY_STRING]
        has_query = query_string && !query_string.empty?
        has_router_params = env.key?(ROUTER_PARAMS)
        has_body_params = env.key?(ACTION_BODY_PARAMS)
        # Only a form-urlencoded/multipart body yields params via Rack; other bodies (e.g. JSON)
        # are handled by BodyParser, which sets ACTION_BODY_PARAMS.
        has_form_body =
          env.key?(RACK_INPUT) && !has_body_params && _form_content_type?(env[CONTENT_TYPE])

        # Fast path: nothing in env produces params, so avoid allocating a Rack::Request.
        return EMPTY_PARAMS unless has_query || has_form_body || has_router_params || has_body_params

        result = {}
        rack_request = ::Rack::Request.new(env) if has_query || has_form_body

        # Query string params first, then form body, then route params, then the BodyParser-parsed
        # body (each later source wins on key collisions).
        result.merge!(rack_request.GET) if has_query
        result.merge!(rack_request.POST) if has_form_body
        result.merge!(env[ROUTER_PARAMS]) if has_router_params
        result.merge!(env[ACTION_BODY_PARAMS]) if has_body_params

        result
      end

      def _form_content_type?(content_type)
        return false unless content_type

        content_type.start_with?("application/x-www-form-urlencoded", "multipart/form-data")
      end
    end
  end
end
