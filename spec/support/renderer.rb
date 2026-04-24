# frozen_string_literal: true

require "json"

module Inspector
  def self.included(action)
    action.class_eval do
      after do |req, res|
        res[:params] = req.params.to_h
        req.env["hanami.response"] = res
      end
    end
  end
end

class Renderer
  def render(env, response)
    action   = env.delete(Hanami::Action::ACTION_INSTANCE)
    response = env.delete("hanami.response") || response

    handle_hanami_response(env, action, response) ||
      handle_rack_response(env, action, response)

    response
  end

  private

  def handle_hanami_response(env, action, response)
    return unless response.respond_to?(:status)

    if response.status == 200 && !head_request?(env)
      response.body = JSON.generate(
        action: action.class.name,
        exposures: response.exposures.reject { |key, _| key == :params || key == :format },
        params: response[:params].to_h,
        flash_now: response.flash.now,
        flash_next: response.flash.next
      )
    end

    true
  end

  def handle_rack_response(env, action, response)
    if response[0] == 200 && !head_request?(env)
      response[2] = JSON.generate(
        action: action.class.name,
        params: env["router.params"].to_h,
        flash_now: env["rack.session"].fetch(Hanami::Action::Flash::KEY, nil),
        flash_next: nil
      )
    end
  end

  def head_request?(env)
    env[Hanami::Action::REQUEST_METHOD] == Hanami::Action::HEAD
  end
end
