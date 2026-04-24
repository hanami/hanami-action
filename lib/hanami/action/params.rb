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

    # A set of params requested by the client
    #
    # It's able to extract the relevant params from a Rack env of from an Hash.
    #
    # There are three scenarios:
    #   * When used with Hanami::Router: it contains only the params from the request
    #   * When used standalone: it contains all the Rack env
    #   * Default: it returns the given hash as it is. It's useful for testing purposes.
    #
    # @since 0.1.0
    class Params
      # Permits all params and returns them as symbolized keys. Stands in for a
      # `Dry::Validation::Contract` when neither {Action.params} nor {Action.contract} are called.
      #
      # @see {Params#initialize}
      #
      # @since 2.2.0
      # @api private
      class DefaultContract
        def self.call(attrs) = Result.new(attrs)

        class Result
          def initialize(attrs) = @attrs = Utils::Hash.deep_symbolize(attrs)
          def to_h = @attrs
          def errors = {}
        end
      end

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
        #     def handle(req, res)
        #       # 1. Don't try to save the record if the params aren't valid
        #       return unless req.params.valid?
        #
        #       BookRepository.new.create(req.params[:book])
        #     rescue Hanami::Model::UniqueConstraintViolationError
        #       # 2. Add an error in case the record wasn't unique
        #       req.params.errors.add(:book, :isbn, "is not unique")
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
        #     def handle(req, *)
        #       puts req.params.to_h   # => {}
        #       puts req.params.valid? # => false
        #       puts req.params.error_messages # => ["Book is missing"]
        #       puts req.params.errors         # => {:book=>["is missing"]}
        #
        #       req.params.errors.add(:book, :isbn, "is not unique") # => ArgumentError
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

      # Defines validations for the params, using the `params` schema of a dry-validation contract.
      #
      # @param block [Proc] the schema definition
      #
      # @see https://dry-rb.org/gems/dry-validation/
      #
      # @api public
      # @since 0.7.0
      def self.params(&block)
        unless defined?(Dry::Validation::Contract)
          message = %(To use `.params`, please add the "dry-validation" gem to your Gemfile)
          raise NoMethodError, message
        end

        @_contract = Class.new(Dry::Validation::Contract) { params(&block || -> {}) }.new
      end

      class << self
        # @api private
        # @since 2.2.0
        attr_reader :_contract
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

        # Fall back to the default contract here, rather than in the `._contract` method itself.
        # This allows `._contract` to return nil when there is no user-defined contract, which is
        # important for the backwards compatibility behavior in `Validatable::ClassMethods#params`.
        contract ||= self.class._contract || DefaultContract
        validation = contract.call(raw)

        @params = validation.to_h
        @errors = Errors.new(validation.errors.to_h)

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
      #       def handle(req, *)
      #         req.params.get(:customer_name)     # => "Luca"
      #         req.params.get(:uknown)            # => nil
      #
      #         req.params.get(:address, :city)    # => "Rome"
      #         req.params.get(:address, :unknown) # => nil
      #
      #         req.params.get(:tags, 0)           # => "foo"
      #         req.params.get(:tags, 1)           # => "bar"
      #         req.params.get(:tags, 999)         # => nil
      #
      #         req.params.get(nil)                # => nil
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

      # @since 0.7.0
      # @api private
      def _extract_params
        result = {}

        unless env.key?(RACK_INPUT)
          result.merge! _parsed_body_params(env)
          return result
        end

        rack_request = ::Rack::Request.new(env)

        # Start with the query string params.
        result.merge!(rack_request.GET)

        # Merge form-urlencoded body params if BodyParser hasn't already consumed the body.
        result.merge!(rack_request.POST) unless env.key?(ACTION_BODY_PARAMS)

        # Merge route params, then finally the BodyParser-parsed body (which wins on collisions).
        result.merge!(env[ROUTER_PARAMS]) if env.key?(ROUTER_PARAMS)
        result.merge!(env[ACTION_BODY_PARAMS]) if env.key?(ACTION_BODY_PARAMS)

        result
      end

      # @since 0.7.0
      # @api private
      def _parsed_body_params(fallback = {})
        env.fetch(ROUTER_PARAMS) { env.fetch(ACTION_BODY_PARAMS, fallback) }
      end
    end
  end
end
