# frozen_string_literal: true

module Hanami
  class Action
    # Support for validating params when calling actions.
    #
    # Included only when dry-validation is bundled.
    #
    # @api private
    # @since 0.1.0
    module Validatable
      # Defines the class name for anonymous params
      #
      # @api private
      # @since 0.3.0
      PARAMS_CLASS_NAME = "Params"

      # @api private
      # @since 0.1.0
      def self.included(base)
        base.extend ClassMethods
      end

      # Validatable API class methods
      #
      # @since 0.1.0
      # @api private
      module ClassMethods
        # Defines a validation schema for the params passed to {Hanami::Action#call}.
        #
        # This feature isn't mandatory, but is highly recommended for secure handling of params:
        # because params come from an untrusted source, it's good practice to filter these to only
        # the keys and types required for your action's use case.
        #
        # The given block is evaluated inside a `params` schema of a `Dry::Validation::Contract`
        # class. This constrains the validation to simple structure and type rules only. If you want
        # to use all the features of dry-validation contracts, use {#contract} instead.
        #
        # The resulting contract becomes part of a dedicated params class for the action, inheriting
        # from {Hanami::Action::Params}.
        #
        # Instead of defining the params validation schema inline, you can alternatively provide a
        # concrete params class, which should inherit from {Hanami::Action::Params}.
        #
        # @param klass [Class,nil] a Hanami::Action::Params subclass
        # @param block [Proc] the params schema definition
        #
        # @return void
        #
        # @see #contract
        # @see Hanami::Action::Params
        # @see https://dry-rb.org/gems/dry-validation/
        #
        # @example Inline definition
        #   require "hanami/action"
        #
        #   class Signup < Hanami::Action
        #     params do
        #       required(:first_name)
        #       required(:last_name)
        #       required(:email)
        #     end
        #
        #     def handle(req, *)
        #       puts req.params.class            # => Signup::Params
        #       puts req.params.class.superclass # => Hanami::Action::Params
        #
        #       puts req.params[:first_name]     # => "Luca"
        #       puts req.params[:admin]          # => nil
        #     end
        #   end
        #
        # @example Concrete class
        #   require "hanami/action"
        #
        #   class SignupParams < Hanami::Action::Params
        #     params do
        #       required(:first_name)
        #       required(:last_name)
        #       required(:email)
        #     end
        #   end
        #
        #   class Signup < Hanami::Action
        #     params SignupParams
        #
        #     def handle(req, *)
        #       puts req.params.class            # => SignupParams
        #       puts req.params.class.superclass # => Hanami::Action::Params
        #
        #       req.params[:first_name]          # => "Luca"
        #       req.params[:admin]               # => nil
        #     end
        #   end
        #
        # @api public
        # @since 0.3.0
        def params(klass = nil, &block)
          contract_class =
            if klass.nil?
              Class.new(Dry::Validation::Contract) { params(&block) }
            elsif klass < Params
              # Handle subclasses of Hanami::Action::Params.
              klass._contract.class
            else
              klass
            end

          config.contract_class = contract_class
        end

        # Defines a validation contract for the params passed to {Hanami::Action#call}.
        #
        # This feature isn't mandatory, but is highly recommended for secure handling of params:
        # because params come from an untrusted source, it's good practice to filter these to only
        # the keys and types required for your action's use case.
        #
        # The given block is evaluated inside a `Dry::Validation::Contract` class. This allows you
        # to use all features of dry-validation contracts
        #
        # The resulting contract becomes part of a dedicated params class for the action, inheriting
        # from {Hanami::Action::Params}.
        #
        # Instead of defining the params validation contract inline, you can alternatively provide a
        # concrete params class, which should inherit from {Hanami::Action::Params}.
        #
        # @param klass [Class,nil] a Hanami::Action::Params subclass
        # @param block [Proc] the params schema definition
        #
        # @return void
        #
        # @see #params
        # @see Hanami::Action::Params
        # @see https://dry-rb.org/gems/dry-validation/
        #
        # @example Inline definition
        #   require "hanami/action"
        #
        #   class Signup < Hanami::Action
        #     contract do
        #       params do
        #         required(:first_name)
        #         required(:last_name)
        #         required(:email)
        #       end
        #
        #       rule(:email) do
        #         # custom rule logic here
        #       end
        #     end
        #
        #     def handle(req, *)
        #       puts req.params.class            # => Signup::Params
        #       puts req.params.class.superclass # => Hanami::Action::Params
        #
        #       puts req.params[:first_name]     # => "Luca"
        #       puts req.params[:admin]          # => nil
        #     end
        #   end
        #
        # @example Concrete class
        #   require "hanami/action"
        #
        #   class SignupParams < Hanami::Action::Params
        #     contract do
        #       params do
        #         required(:first_name)
        #         required(:last_name)
        #         required(:email)
        #       end
        #
        #       rule(:email) do
        #         # custom rule logic here
        #       end
        #     end
        #   end
        #
        #   class Signup < Hanami::Action
        #     params SignupParams
        #
        #     def handle(req, *)
        #       puts req.params.class            # => SignupParams
        #       puts req.params.class.superclass # => Hanami::Action::Params
        #
        #       req.params[:first_name]          # => "Luca"
        #       req.params[:admin]               # => nil
        #     end
        #   end
        #
        # @api public
        # @since 2.2.0
        def contract(klass = nil, &block)
          contract_class = klass || Class.new(Dry::Validation::Contract, &block)

          config.contract_class = contract_class
        end
      end
    end
  end
end
