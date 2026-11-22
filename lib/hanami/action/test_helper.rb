# frozen_string_literal: true

module Hanami
  class Action
    # Testing conveniences for calling actions directly.
    #
    # Prepend this module in test environments only. It allows actions to be
    # called with a bare params hash and/or a session hash, instead of a full
    # Rack env:
    #
    # @example
    #   Hanami::Action.prepend(Hanami::Action::TestHelper)
    #
    #   action.call(params: {id: 1}, session: {user_id: 2})
    #
    # @since 3.1.0
    # @api public
    module TestHelper
      # @see Hanami::Action#call
      #
      # @since 3.1.0
      # @api public
      def call(env = nil, params: nil, session: nil, **rest)
        env = params if params.is_a?(Hash) && env.nil?
        env ||= rest

        # Ensure env has REQUEST_METHOD for downstream code (e.g. Response) when
        # actions are called with a direct params hash.
        env[REQUEST_METHOD] ||= DEFAULT_REQUEST_METHOD
        env[RACK_SESSION] = session if session && session_enabled?

        super(env)
      end
    end
  end
end
