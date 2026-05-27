# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

### Changed

- Renamed gem from hanami-controller to hanami-action. You should now `require "hanami-action"` or `require "hanami/action"`. (@timriley in #507)

### Deprecated

### Removed

- Removed `Hanami::Action::Params.params` and support for defining a contract by subclassing `Hanami::Action::Params`. If you are subclassing `Hanami::Action::Params`, take your params block and move it into a `Dry::Validation::Contract` subclass.  Then pass this contract class to `Hanami::Action.params` or `Hanami::Action.contract`. (@timriley)

  ```ruby
  # Before
  # class SignupParams < Hanami::Action::Params
  #   params do
  #     required(:email).filled(:str?)
  #   end
  # end
  
  # After
  class SignupContract < Dry::Validation::Contract
    params do
      required(:email).filled(:str?)
    end
  end
  
  class Signup < Hanami::Action
    params SignupParams
  end
  ```

### Fixed

### Security

[Unreleased]: https://github.com/hanami/hanami-action/compare/v2.3.1...main

## [2.3.1] - 2025-12-06

### Fixed

- Allow `handle_exception` to receive multiple class names as strings. (@sidane in #495)

  ```ruby
  class MyAction < Hanami::Action
    config.handle_exception(
      "MyException" => 500,
      "MyOtherException" => 501
    )
  end
  ```

[2.3.1]: https://github.com/hanami/hanami-action/compare/v2.3.0...v2.3.1

## [2.3.0] - 2025-11-12

### Added

- Fetch CSRF tokens from `X-CSRF-Token` request header, in addition to body params. (@masterT in #422)

### Changed

- Allow `config.handle_exception` to receive an exception class name as a string. (@mathewdbutton in #488)

  This allows you to handle exceptions in your actions without having to require the Ruby files that define the exception constants, which is often awkward if those exceptions come from far-removed layers of your app.

  ```ruby
  class MyAction < Hanami::Action
    config.handle_exception "ROM::TupleCountMismatchError" => 404
  end
  ```
- Allow both `:unprocessable_entity` and `:unprocessable_content` and to be used to refer to the 422 HTTP status code (Rack v3 dropped the former and replaced it with the latter). (@alassek in #490)

  ```ruby
  def handle(request, response)
    # Or :unprocessable_content, both work, on all Rack versions
    response.status = :unprocessable_entity
  end
  ```

[2.3.0]: https://github.com/hanami/hanami-action/compare/v2.3.0.beta2...v2.3.0

## [2.3.0.beta2] - 2025-10-17

### Added

- Make format config more flexible. (Tim Riley in #485)

  **Use `config.formats.register` to register a new format and its media types.**

  This replaces `config.formats.add`. Unlike `.add` it does _not_ set the format as being one of the accpeted formats at the same time.

  This change makes it easier to `register` your custom formats in app config or a base action class, without inadvertently causing format restrictions in descendent action classes.

  A simple registration looks like this:

  ```ruby
  config.formats.register(:json, "application/json")
  ```

  `.register` also allows you to register one or more media types for the distinct stages of request processing:

  - If you want to accept requests based on different/additional media types in `Accept` request headers, provide them as `accept_types:`
  - If you want to accept requests based on different/additional media types in `Content-Type` request headers, provide them as `content_types:`
  - If you do not provide these options, then the _default_ media type (the required second argument, after the format name) is used for each of the above
  - This default media type is also set as the default `Content-Type` _response_ header for requests that match the format

  Together, these allow you to register a format like this:

  ```ruby
  config.formats.register(
    :jsonapi,
    "application/vnd.api+json",
    accept_types: ["application/vnd.api+json", "application/json"],
    content_types: ["application/vnd.api+json", "application/json"],
  )
  ```

  **Use `config.formats.accept` to accept specific formats from an action.**

  `formats.accept` replaces `Action.format` and `config.format`. You can access your accepted formats via `formats.accepted`, which replaces `config.formats.values`.

  To accept a format:

  ```ruby
  config.formats.accept :html, :json
  config.formats.accepted # => [:html, :json]

  config.formats.accept :csv # it is additive
  config.formats.accepted # => [:html, :json, :csv]
  ```

  The first format you give to `accept` will also become the _default format_ for responses from your action.

  **Use config.formats.default=` to set an action's default format.**

  This is a new capability. Assign an action's default format using `config.formats.default=`.

  The default format is used to set the response `Content-Type` header when the request does not specify a format via `Accept`.

  ```ruby
  config.formats.accept :html, :json

  # When no default is already set, the first accepted format becomes default
  config.formats.default # => :html

  # But you can now configure this directly
  config.formats.default = :json
  ```

### Changed

- `Action.format`, `config.format`, `config.formats.add`, `config.formats.values`, and `config.formats.values=` are deprecated and will be removed in Hanami 2.4. (Tim Riley in #485)
- Drop support for Ruby 3.1. (Tim Riley in #485)

[2.3.0.beta2]: https://github.com/hanami/hanami-action/compare/v2.3.0.beta1...v2.3.0.beta2

## [2.3.0.beta1] - 2025-10-03

### Added

- Add `Request#subdomains`, returning an array of subdomains for the current host, and `Request#subdomain` returning a dot-delimited subdomain string for the current host. Add `config.default_tld_length` setting for configuring the TLD length for your app's expected domain. (Wout in #481)

### Changed

- Support Rack 3 in addition to Rack 2. (Kyle Plump, Tim Riley in #460)
- `request.session` is now an instance of `Hanami::Action::Request::Session`, which wraps the session object and provides access to session values via symbol keys. This was previously handled via symbolizing and reassigning the entire session hash, which is not compatible with Rack 3. (Tim Riley in #477)

### Fixed

- Avoid false negatives in format/content type matches by checking against the request's media type, which excludes content type parameters (e.g. "test/plain" instead of "text/plain;charset=utf-8"). (wuarmin in #471)

[2.3.0.beta1]: https://github.com/hanami/hanami-action/compare/v2.2.0...v2.3.0.beta1

## [2.2.0] - 2024-11-05

### Added

- When an action is called, add the action instance to the Rack environment under the `"hanami.action_instance"` key. (Tom de Bruijn, Tim Riley in #446)

[2.2.0]: https://github.com/hanami/hanami-action/compare/v2.2.0.rc1...v2.2.0

## [2.2.0.rc1] - 2024-10-29

[2.2.0.rc1]: https://github.com/hanami/hanami-action/compare/v2.2.0.beta2...v2.2.0.rc1

## [2.2.0.beta2] - 2024-09-25

### Added

- Add support for using full dry-validation contracts for action param validation, via `Hanami::Action.contract`. (Tim Riley, Krzysztof Piotrowski in #453, #454)

[2.2.0.beta2]: https://github.com/hanami/hanami-action/compare/v2.2.0.beta1...v2.2.0.beta2

## [2.2.0.beta1] - 2024-07-16

### Changed

- Drop support for Ruby 3.0. (Tim Riley in #454)

[2.2.0.beta1]: https://github.com/hanami/hanami-action/compare/v2.1.0...v2.2.0.beta1

## [2.1.0] - 2024-02-27

[2.1.0]: https://github.com/hanami/hanami-action/compare/v2.1.0.rc3...v2.1.0

## [2.1.0.rc3] - 2024-02-16

[2.1.0.rc3]: https://github.com/hanami/hanami-action/compare/v2.1.0.rc2...v2.1.0.rc3

## [2.1.0.rc2] - 2023-11-08

[2.1.0.rc2]: https://github.com/hanami/hanami-action/compare/v2.1.0.rc1...v2.1.0.rc2

## [2.1.0.rc1] - 2023-11-01

### Fixed

- Ensure Rack compatibility of `Hanami::Action::Response#send_file`. (Luca Guidi in #431)

[2.1.0.rc1]: https://github.com/hanami/hanami-action/compare/v2.1.0.beta2...v2.1.0.rc1

## [2.1.0.beta2] - 2023-10-04

### Fixed

- `Hanami::Action::Config#root`: don't check realpath existence to simplify the boot process of Hanami. (Luca Guidi in #429)

[2.1.0.beta2]: https://github.com/hanami/hanami-action/compare/v2.1.0.beta1...v2.1.0.beta2

## [2.1.0.beta1] - 2023-06-29

### Added

- Add `Request#session_enabled?` and `Response#session_enabled?`. (Tim Riley in #423)

[2.1.0.beta1]: https://github.com/hanami/hanami-action/compare/v2.0.2...v2.1.0.beta1

## [2.0.2] - 2023-02-01

### Added

- Params Pattern Matching. (Adam Lassek in #417)
- Allow to `halt` using a `Symbol`: `halt :unauthorized`. (Adam Lassek, Luca Guidi in #418)
- Introduce `Hanami::Action::Response#status=` to accept an `Integer` or a `Symbol`. (Adam Lassek, Luca Guidi in #418)

### Fixed

- Ensure action accepting the request with a custom MIME Type. (Pat Allan in #409)
- Halting with an unknown HTTP code will raise a `Hanami::Action::UnknownHttpStatusError`. (Luca Guidi in #418)
- Fix error message for missing format (MIME Type). (Luca Guidi in #418)

[2.0.2]: https://github.com/hanami/hanami-action/compare/v2.0.1...v2.0.2

## [2.0.1] - 2022-12-25

### Added

- Official support for Ruby 3.2. (Luca Guidi in #408)

[2.0.1]: https://github.com/hanami/hanami-action/compare/v2.0.0...v2.0.1

## [2.0.0] - 2022-11-22

### Added

- Use Zeitwerk to autoload the gem. (Tim Riley in #401)
- Introduce `Hanami::Action::Config#formats`. Use `config.actions.formats.add(:json)`. Custom formats can use `config.actions.formats.add(:graphql, ["application/graphql"])`. (Tim Riley in #401)

### Changed

- Changed `Hanami::Action::Config#format` semantic: it's no longer used to add custom MIME Types, but as a macro to setup the wanted format for action(s). (Tim Riley in #401)
- Removed `Hanami::Action::Config#default_request_format` and `#default_response_format`, use `#format` for both. (Tim Riley in #401)
- Removed `Hanami::Action::Config#accept`, use `#format`. (Tim Riley in #401)

[2.0.0]: https://github.com/hanami/hanami-action/compare/v2.0.0.rc1...v2.0.0

## [2.0.0.rc1] - 2022-11-08

### Changed

- Simplify assignment of response format: `response.format = :json` (was `response.format = format(:json)`). (Tim Riley in #400)

[2.0.0.rc1]: https://github.com/hanami/hanami-action/compare/v2.0.0.beta4...v2.0.0.rc1

## [2.0.0.beta4] - 2022-10-24

### Added

- Add `Response#flash`, and delgate to request object for both `Response#session` and `Response#flash`, ensuring the same objects are used when accessed via either request or response. (Tim Riley in #399)

### Changed

- When `Action.accept` is declared (or `Action::Config.accepted_formats` configured), return a 406 error if an `Accept` request header is present but is not acceptable. In the absence of an `Accept` header, return a 415 error if a `Content-Type` header is present but not acceptable. If neither header is provided, accept the request. (Tim Riley in #396)
- Add `Action.handle_exception` class method as a shortcut for `Hanami::Action::Config#handle_exception`. (Tim Riley in #394)
- Significantly reduce memory usage by leveraging recent dry-configurable changes, and relocating `accepted_formats`, `before_callbacks`, `after_callbacks` inheritable attributes to `config`. (Tim Riley in #392)
- Make params validation schemas (defined in `params do` block) inheritable to subclasses. (Tim Riley in #394)
- Raise `Hanami::Action::MissingSessionError` with a friendly message if `Request#session`, `Request#flash`, `Response#session` or `Response#flash` are called for an action that does not already include `Hanami::Action:Session` mixin. (Benhamin Klotz, Tim Riley in #379, #395)

### Fixed

- When a params validation schema is provided (in a `params do` block), only return the validated params from `request.params`. (Benjamin Klotz in #375)
- Handle dry-schema's messages hash now being frozen by default. (Sean Collins in #391)

[2.0.0.beta4]: https://github.com/hanami/hanami-action/compare/v2.0.0.beta1...v2.0.0.beta4

## [2.0.0.beta1] - 2022-07-20

### Fixed

- Using `Hanami::Action.params` without having `hanami-validations` installed now returns a user-friendly error. (Benjamin Klotz in #371)
- Ensure HEAD responses to send empty body, but preserve headers. (Narinda Reeders in #368)
- Ensure HEAD redirect responses to return redirect headers. (Narinda Reeders in #368)
- Do not automatically render halted requests. (Andrew Croome in #364)

[2.0.0.beta1]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha8...v2.0.0.beta1

## [2.0.0.alpha8] - 2022-02-19

### Changed

- Removed automatic integration of `Hanami::Action` subclasses with their surrounding Hanami application. Action base classes within Hanami apps should inherit from `Hanami::Application::Action` instead. (Tim Riley in #362)

[2.0.0.alpha8]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha6...v2.0.0.alpha8

## [2.0.0.alpha6] - 2022-02-10

### Added

- Official support for Ruby: MRI 3.1. (Luca Guidi in #359)

### Changed

- Drop support for Ruby: MRI 2.6, and 2.7. (Luca Guidi in #359)
- Align with Rack list of HTTP supported status. Added: `103`, `306`, `421`, `425`, `451`, and `509`. Removed: `418`, `420`, `444`, `449`, `450`, `451`, `499`, `598`, `599`. (Sean Collins in #358)

[2.0.0.alpha6]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha5...v2.0.0.alpha6

## [2.0.0.alpha5] - 2022-01-12

### Added

- Added "rss" ("application/rss+xml") to list of supported MIME types. (Philip Arndt in #357)

[2.0.0.alpha5]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha4...v2.0.0.alpha5

## [2.0.0.alpha4] - 2021-12-07

### Added

- Manage Content Security Policy (CSP) defaults and new API via `Hanami::Action::ApplicationConfiguration#content_security_policy`. (Luca Guidi in #354)
- Provide access to routes inside all application actions via `Hanami::Action::ApplicationAction#routes`. (Tim Riley & Marc Busqué in #352)

[2.0.0.alpha4]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha3...v2.0.0.alpha4

## [2.0.0.alpha3] - 2021-11-09

### Added

- Automatically include session behavior in `Hanami::Action` when sessions are enabled via Hanami application config. (Luca Guidi in #347)
- Pass exposures from action to view. (Sean Collins in #348)

### Changed

- (Internal) Updated settings to use updated `setting` API in dry-configurable 0.13.0. (Tim Riley in #346)
- Move automatic view rendering from `handle` to `finish`. (Sean Collins in #348)

[2.0.0.alpha3]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha2...v2.0.0.alpha3

## [2.0.0.alpha2] - 2021-05-04

### Added

- Official support for Ruby: MRI 3.0. (Luca Guidi in #325)
- Introduced `Hanami::Action::ApplicationAction`. (Tim Riley in #325)
- Introduced `Hanami::Action::Configuration`. (Tim Riley in #325)
- Introduced `Hanami::Action::ApplicationConfiguration`. (Tim Riley in #325)
- Auto-inject a paired view into any `Hanami::Action::ApplicationAction` instance. (Tim Riley in #325)
- Auto-render `Hanami::Action::ApplicationAction` subclasses that don't implement `#handle`. (Tim Riley in #325)
- Enable CSRF protection automatically when HTTP sessions are enabled. (Tim Riley in #325)

### Changed

- Drop support for Ruby: MRI 2.5. (Luca Guidi in #325)
- Removed `Hanami::Action.handle_exception` in favor of `Hanami::Action.config.handle_exception`. (Tim Riley in #325)
- Rewritten `Hanami::Action::Flash`, based on Roda's `FlashHash`. (Tim Riley in #325)

### Fixed

- Ensure `Hanami::Action::Response#renderable?` to return `false` when body is set. (Luca Guidi in #325)
- Ensure `Hanami::Action.accept` to use Rack `CONTENT_TYPE` for the _before callback_ check. (Andrew Croome in #325)

[2.0.0.alpha2]: https://github.com/hanami/hanami-action/compare/v2.0.0.alpha1...v2.0.0.alpha2

## [2.0.0.alpha1] - 2019-01-30

### Added

- `Hanami::Action::Request#session` to access the HTTP session as it was originally sent. (Luca Guidi in #281)
- `Hanami::Action::Request#cookies` to access the HTTP cookies as they were originally sent. (Luca Guidi in #281)
- Allow to build a deep inheritance chain for actions. (Luca Guidi & Tim Riley in #281)

### Changed

- Drop support for Ruby: MRI 2.3, and 2.4. (Luca Guidi in #281)
- `Hanami::Action` is a superclass. (Luca Guidi in #281)
- `Hanami::Action#initialize` requires a `configuration:` keyword argument. (Luca Guidi in #281)
- `Hanami::Action#initialize` returns a frozen action instance. (Luca Guidi in #281)
- `Hanami::Action` subclasses must implement `#handle` instead of `#call`. (Tim Riley in #281)
- `Hanami::Action#handle` accepts `Hanami::Action::Request` and `Hanami::Action::Response`. (Luca Guidi in #281)
- `Hanami::Action#handle` returns `Hanami::Action::Response`. (Luca Guidi in #281)
- Removed `Hanami::Controller.configure`, `.configuration`, `.duplicate`, and `.load!`. (Luca Guidi in #281)
- Removed `Hanami::Action.use` to mount Rack middleware at the action level. (Luca Guidi in #281)
- `Hanami::Controller::Configuration` changed syntax from DSL style to setters (eg. `Hanami::Controller::Configuration.new { |c| c.default_request_format = :html }`). (Luca Guidi in #281)
- `Hanami::Controller::Configuration#initialize` returns a frozen configuration instance. (Luca Guidi in #281)
- Removed `Hanami::Controller::Configuration#prepare`. (Luca Guidi in #281)
- Removed `Hanami::Action.configuration`. (Luca Guidi in #281)
- Removed `Hanami::Action.configuration.handle_exceptions`. (Luca Guidi in #281)
- Removed `Hanami::Action.configuration.default_request_format` in favor of `#default_request_format`. (Luca Guidi in #281)
- Removed `Hanami::Action.configuration.default_charset` in favor of `#default_charset`. (Luca Guidi in #281)
- Removed `Hanami::Action.configuration.format` to register a MIME Type for a single action. Please use the configuration. (Luca Guidi in #281)
- Removed `Hanami::Action.expose` in favor of `Hanami::Action::Response#[]=` and `#[]`. (Luca Guidi in #281)
- Removed `Hanami::Action#status=` in favor of `Hanami::Action::Response#status=`. (Luca Guidi in #281)
- Removed `Hanami::Action#body=` in favor of `Hanami::Action::Response#body=`. (Luca Guidi in #281)
- Removed `Hanami::Action#headers` in favor of `Hanami::Action::Response#headers`. (Luca Guidi in #281)
- Removed `Hanami::Action#accept?` in favor of `Hanami::Action::Request#accept?`. (Luca Guidi in #281)
- Removed `Hanami::Action#format` in favor of `Hanami::Action::Response#format`. (Luca Guidi in #281)
- Introduced `Hanami::Action#format` as factory to assign response format: `res.format = format(:json)` or `res.format = format("application/json")`. (Luca Guidi in #281)
- Removed `Hanami::Action#format=` in favor of `Hanami::Action::Response#format=`. (Luca Guidi in #281)
- `Hanami::Action.accept` now looks at request `Content-Type` header to accept/deny a request. (Gustavo Caso in #281)
- Removed `Hanami::Action#request_id` in favor of `Hanami::Action::Request#id`. (Luca Guidi in #281)
- Removed `Hanami::Action#parsed_request_body` in favor of `Hanami::Action::Request#parsed_body`. (Gustavo Caso in #281)
- Removed `Hanami::Action#head?` in favor of `Hanami::Action::Request#head?`. (Luca Guidi in #281)
- Removed `Hanami::Action#status` in favor of `Hanami::Action::Response#status=` and `#body=`. (Luca Guidi in #281)
- Removed `Hanami::Action#session` in favor of `Hanami::Action::Response#session`. (Luca Guidi in #281)
- Removed `Hanami::Action#cookies` in favor of `Hanami::Action::Response#cookies`. (Luca Guidi in #281)
- Removed `Hanami::Action#flash` in favor of `Hanami::Action::Response#flash`. (Luca Guidi in #281)
- Removed `Hanami::Action#redirect_to` in favor of `Hanami::Action::Response#redirect_to`. (Luca Guidi in #281)
- Removed `Hanami::Action#cache_control`, `#expires`, and `#fresh` in favor of `Hanami::Action::Response#cache_control`, `#expires`, and `#fresh`, respectively. (Luca Guidi in #281)
- Removed `Hanami::Action#send_file` and `#unsafe_send_file` in favor of `Hanami::Action::Response#send_file` and `#unsafe_send_file`, respectively. (Luca Guidi in #281)
- Removed `Hanami::Action#errors`. (Luca Guidi in #281)
- Removed body cleanup for `HEAD` requests. (Gustavo Caso in #281)
- `Hanami::Action` callback hooks now accept `Hanami::Action::Request` and `Hanami::Action::Response` arguments. (Luca Guidi in #281)
- When an exception is raised, it won't be caught, unless it's handled. (Luca Guidi in #281)
- `Hanami::Action` exception handlers now accept `Hanami::Action::Request`, `Hanami::Action::Response`, and exception arguments. (Luca Guidi in #281)

[2.0.0.alpha1]: https://github.com/hanami/hanami-action/compare/v1.3.3...v2.0.0.alpha1

## [1.3.3] - 2020-01-14

### Added

- Official support for Ruby: MRI 2.7. (Luca Guidi in #323)
- Support `rack` 2.1. (Luca Guidi in #323)
- Support for both `hanami-validations` 1 and 2. (Luca Guidi in #323)

[1.3.3]: https://github.com/hanami/hanami-action/compare/v1.3.2...v1.3.3

## [1.3.2] - 2019-06-28

### Fixed

- Ensure `Etag` to work when `If-Modified-Since` is sent from browser and upstream proxy sets `Last-Modified` automatically. (Ian Ker-Seymer in #321)

[1.3.2]: https://github.com/hanami/hanami-action/compare/v1.3.1...v1.3.2

## [1.3.1] - 2019-01-18

### Added

- Official support for Ruby: MRI 2.6. (Luca Guidi in #317)
- Support `bundler` 2.0+. (Luca Guidi in #317)

[1.3.1]: https://github.com/hanami/hanami-action/compare/v1.3.0...v1.3.1

## [1.3.0] - 2018-10-24

### Added

- Swappable JSON backed for `Hanami::Action::Flash` based on `Hanami::Utils::Json`. (Gustavo Caso in #306)

[1.3.0]: https://github.com/hanami/hanami-action/compare/v1.3.0.beta1...v1.3.0

## [1.3.0.beta1] - 2018-08-08

### Added

- Official support for JRuby 9.2.0.0. (Luca Guidi in #303)

### Changed

- Deprecate `Hanami::Action#parsed_request_body`. (Gustavo Caso in #302)

### Fixed

- Ensure that if `If-None-Match` or `If-Modified-Since` response HTTP headers are missing, `Etag` or `Last-Modified` headers will be in response HTTP headers. (Yuji Ueki in #299)
- Don't show flash message for the request after a HTTP redirect. (Gustavo Caso in #301)
- Ensure `Hanami::Action::Flash#each`, `#map`, and `#empty?` to not reference stale flash data. (Gustavo Caso in #301)

[1.3.0.beta1]: https://github.com/hanami/hanami-action/compare/v1.2.0...v1.3.0.beta1

## [1.2.0] - 2018-04-11

[1.2.0]: https://github.com/hanami/hanami-action/compare/v1.2.0.rc2...v1.2.0

## [1.2.0.rc2] - 2018-04-06

### Added

- Introduce `Hanami::Action::Flash#each` and `#map`. (Gustavo Caso in #294)

[1.2.0.rc2]: https://github.com/hanami/hanami-action/compare/v1.2.0.rc1...v1.2.0.rc2

## [1.2.0.rc1] - 2018-03-30

[1.2.0.rc1]: https://github.com/hanami/hanami-action/compare/v1.2.0.beta2...v1.2.0.rc1

## [1.2.0.beta2] - 2018-03-23

[1.2.0.beta2]: https://github.com/hanami/hanami-action/compare/v1.2.0.beta1...v1.2.0.beta2

## [1.2.0.beta1] - 2018-02-28

### Added

- Official support for Ruby: MRI 2.5. (Luca Guidi in #290)
- Introduce `Hanami::Action.content_type` to accept/reject requests according to their `Content-Type` header. (Sergey Fedorov in #207)

### Fixed

- Raise meaningful exception when trying to access `session` or `flash` and `Hanami::Action::Session` wasn't included. (wheresmyjetpack in #207)

[1.2.0.beta1]: https://github.com/hanami/hanami-action/compare/v1.1.1...v1.2.0.beta1

## [1.1.1] - 2017-11-22

### Fixed

- Ensure `Hanami::Action#send_file` and `#unsafe_send_file` to run `after` action callbacks. (Luca Guidi in #282)
- Ensure Rack env to have the `REQUEST_METHOD` key set to `GET` during actions unit tests. (Luca Guidi in #282)

[1.1.1]: https://github.com/hanami/hanami-action/compare/v1.1.0...v1.1.1

## [1.1.0] - 2017-10-25

### Added

- Introduce `Hanami::Action::CookieJar#each` to iterate through action's `cookies`. (Luca Guidi in #279)

[1.1.0]: https://github.com/hanami/hanami-action/compare/v1.1.0.rc1...v1.1.0

## [1.1.0.rc1] - 2017-10-16

[1.1.0.rc1]: https://github.com/hanami/hanami-action/compare/v1.1.0.beta3...v1.1.0.rc1

## [1.1.0.beta3] - 2017-10-04

[1.1.0.beta3]: https://github.com/hanami/hanami-action/compare/v1.1.0.beta2...v1.1.0.beta3

## [1.1.0.beta2] - 2017-10-03

### Added

- Introduce `Hanami::Action::Params::Errors#add` to add errors not generated by params validations. (Luca Guidi in #276)

[1.1.0.beta2]: https://github.com/hanami/hanami-action/compare/v1.1.0.beta1...v1.1.0.beta2

## [1.1.0.beta1] - 2017-08-11

[1.1.0.beta1]: https://github.com/hanami/hanami-action/compare/v1.0.1...v1.1.0.beta1

## [1.0.1] - 2017-07-10

### Fixed

- Ensure validation params to be symbolized in all the environments. (Marcello Rocha in #269)
- Fix regression (`1.0.0`) about MIME type priority, during the evaluation of a weighted `Accept` HTTP header. (Marcello Rocha in #269)

[1.0.1]: https://github.com/hanami/hanami-action/compare/v1.0.0...v1.0.1

## [1.0.0] - 2017-04-06

[1.0.0]: https://github.com/hanami/hanami-action/compare/v1.0.0.rc1...v1.0.0

## [1.0.0.rc1] - 2017-03-31

[1.0.0.rc1]: https://github.com/hanami/hanami-action/compare/v1.0.0.beta3...v1.0.0.rc1

## [1.0.0.beta3] - 2017-03-17

### Changed

- `Action#flash` is now public API. (Luca Guidi in #262)

[1.0.0.beta3]: https://github.com/hanami/hanami-action/compare/v1.0.0.beta2...v1.0.0.beta3

## [1.0.0.beta2] - 2017-03-02

### Added

- Add `Action#unsafe_send_file` to send files outside of the public directory of a project. (Marcello Rocha in #257)

### Fixed

- Ensure HTTP Cache to not crash when `HTTP_IF_MODIFIED_SINCE` and `HTTP_IF_NONE_MATCH` have blank values. (Anton Davydov in #253)
- Keep flash values after a redirect. (Luca Guidi in #259)
- Ensure to return 404 when `Action#send_file` cannot find a file with a globbed route. (Craig M. Wellington & Luca Guidi in #260)
- Don't mutate Rack env when sending files. (Luca Guidi in #260)

[1.0.0.beta2]: https://github.com/hanami/hanami-action/compare/v1.0.0.beta1...v1.0.0.beta2

## [1.0.0.beta1] - 2017-02-14

### Added

- Official support for Ruby: MRI 2.4. (Luca Guidi in #236)

### Changed

- Make it work only with Rack 2.0. (Anton Davydov & Luca Guidi in #239)

### Fixed

- Avoid MIME type conflicts for `Action#format` detection. (Marcello Rocha & Luca Guidi in #255)
- Ensure `Flash` to return only fresh data. (Matias H. Leidemer & Luca Guidi in #jardakotesovec)
- Ensure `session` keys to be accessed as symbols in action unit tests. (Luca Guidi in #237)

[1.0.0.beta1]: https://github.com/hanami/hanami-action/compare/v0.8.1...v1.0.0.beta1

## [0.8.1] - 2016-12-19

### Added

- Add `flash` to the default exposures. (Luca Guidi in #233)

### Fixed

- Don't pollute Rack env's `rack.exception` key if an exception is handled. (Thorbjørn Hermansen in #234)

[0.8.1]: https://github.com/hanami/hanami-action/compare/v0.8.0...v0.8.1

## [0.8.0] - 2016-11-15

### Added

- Allow `BaseParams#get` to read (nested) arrays. (Marion Duprey in #227)

### Changed

- Let `BaseParams#get` to accept a list of keys (symbols) instead of string with dot notation (`params.get(:customer, :address, :city)` instead of `params.get('customer.address.city')`). (Luca Guidi in #229)

### Fixed

- Respect custom formats when referenced by HTTP `Accept`. (Russell Cloak in #221)
- Don't symbolize raw params. (Kyle Chong in #224)

[0.8.0]: https://github.com/hanami/hanami-action/compare/v0.7.1...v0.8.0

## [0.7.1] - 2016-10-06

### Added

- Introduced `parsed_request_body` for action. (Kyle Chong in #155)
- Introduced `Hanami::Action::BaseParams#each`. (Luca Guidi in #176)

### Changed

- Raise `Hanami::Controller::IllegalExposureError` when try to expose reserved words: `params`, and `flash`. (akhramov & Luca Guidi in #195)

### Fixed

- Use default content type when `HTTP_ACCEPT` is `*/*`. (Ayleen McCann in #211)
- Don't stringify uploaded files. (Kyle Chong in #213)
- Don't stringify params values when not necessary. (Kyle Chong in #214)

[0.7.1]: https://github.com/hanami/hanami-action/compare/v0.7.0...v0.7.1

## [0.7.0] - 2016-07-22

### Added

- Introduced `Hanami::Action::Params#error_messages` which returns a flat collection of full error messages. (Luca Guidi in #165)
- Nested params validation. (Steve Hodgkiss in #168)

### Changed

- Drop support for Ruby 2.0 and 2.1. Official support for JRuby 9.0.5.0+. (Luca Guidi in #verbman)
- Param validations now require you to add `hanami-validations` in `Gemfile`. (Luca Guidi in #verbman)
- Removed "_indifferent access_" for params. Since now on, only symbols are allowed. (Luca Guidi in #verbman)
- Params are immutable. (Luca Guidi in #verbman)
- Params validations syntax has changed. (Luca Guidi in #verbman)
- `Hanami::Action::Params#errors` now returns a Hash. Keys are symbols representing invalid params, while values are arrays of strings with a message of the failure. (Luca Guidi in #verbman)
- Made `Hanami::Action::Session#errors` public. (Vasilis Spilka in #171)

### Fixed

- Params are deeply symbolized. (Luca Guidi in #verbman)
- Send only changed cookies in HTTP response. (Artem Nistratov in #153)

[0.7.0]: https://github.com/hanami/hanami-action/compare/v0.6.1...v0.7.0

## [0.6.1] - 2016-02-05

### Changed

- Optimise memory usage by freezing MIME types constant. (Anatolii Didukh in #152)

[0.6.1]: https://github.com/hanami/hanami-action/compare/v0.6.0...v0.6.1

## [0.6.0] - 2016-01-22

### Changed

- Renamed the project. (Luca Guidi)

[0.6.0]: https://github.com/hanami/hanami-action/compare/v0.5.1...v0.6.0

## [0.5.1] - 2016-01-19

### Fixed

- Ensure `rack.session` cookie to not be sent twice when both `Lotus::Action::Cookies` and `Rack::Session::Cookie` are used together. (Alfonso Uceda in #148)

[0.5.1]: https://github.com/hanami/hanami-action/compare/v0.5.0...v0.5.1

## [0.5.0] - 2016-01-12

### Added

- Reference a raised exception in Rack env's `rack.exception`. Compatibility with exception reporting SaaS. (Luca Guidi in #129)

### Changed

- Removed `Lotus::Controller::Configuration#default_format`. (Luca Guidi)
- Made `Lotus::Action#session` a public method for improved unit testing. (Cainã Costa in #135)
- Introduced `Lotus::Controller::Error` and let all the framework exceptions to inherit from it. (Karim Tarek in #147)

### Fixed

- Ensure superclass exceptions to not shadow subclasses during exception handling (eg. `CustomError` handler will take precedence over `StandardError`). (Luca Guidi)
- Ensure Rack environment to be always available for sessions unit tests. (Cainã Costa in #135)

[0.5.0]: https://github.com/hanami/hanami-action/compare/v0.4.6...v0.5.0

## [0.4.6] - 2015-12-04

### Added

- Allow to force custom headers for responses that according to RFC shouldn't include them (eg 204). Override `#keep_response_header?(header)` in action. (Luca Guidi in #124)

[0.4.6]: https://github.com/hanami/hanami-action/compare/v0.4.5...v0.4.6

## [0.4.5] - 2015-09-30

### Added

- Added configuration entries: `#default_request_format` and `default_response_format`. (Theo Felippe in #122)
- Error handling to take account of inherited exceptions. (Wellington Santos in #127)

### Deprecated

- Deprecate `#default_format` in favor of: `#default_request_format`. (Theo Felippe in #122)

[0.4.5]: https://github.com/hanami/hanami-action/compare/v0.4.4...v0.4.5

## [0.4.4] - 2015-06-23

### Added

- Security protection against Cross Site Request Forgery (CSRF). (Luca Guidi in #118)

### Fixed

- Ensure nested params to be correctly coerced to Hash. (Matthew Bellantoni in #107)

[0.4.4]: https://github.com/hanami/hanami-action/compare/v0.4.3...v0.4.4

## [0.4.3] - 2015-05-22

### Added

- Introduced `Lotus::Action#send_file`. (Alfonso Uceda Pompa in #105)
- Set automatically `Expires` option for cookies when it's missing but `Max-Age` is present. Compatibility with old browsers. (Alfonso Uceda Pompa in #102)

[0.4.3]: https://github.com/hanami/hanami-action/compare/v0.4.2...v0.4.3

## [0.4.2] - 2015-05-15

### Fixed

- Ensure `Lotus::Action::Params#to_h` to return `::Hash` at the top level. (Luca Guidi in #101)

[0.4.2]: https://github.com/hanami/hanami-action/compare/v0.4.1...v0.4.2

## [0.4.1] - 2015-05-15

### Changed

- Prevent `Content-Type` and `Content-Lenght` to be sent when status code requires no body (eg. `204`). This is for compatibility with `Rack::Lint`, not with RFC 2016. (Alfonso Uceda Pompa in #99)
- Ensure `Lotus::Action::Params#to_h` to return `::Hash`. (Luca Guidi in #96)

### Fixed

- Ensure proper automatic `Content-Type` working well with Internet Explorer. (Luca Guidi in #94)
- Ensure `Lotus::Action#redirect_to` to return `::String` for Rack servers compatibility. (Luca Guidi in #95)

[0.4.1]: https://github.com/hanami/hanami-action/compare/v0.4.0...v0.4.1

## [0.4.0] - 2015-03-23

### Added

- `Action.use` now accepts a block. (Erol Fornoles in #70)
- Introduced `Lotus::Controller::Configuration#cookies` as default cookie options. (Alfonso Uceda Pompa in #77)
- Introduced `Lotus::Controller::Configuration#default_headers` as default HTTP headers to return in all the responses. (Alfonso Uceda Pompa in #82)
- Introduced `Lotus::Action::Params#get` as a safe API to access nested params. (Luca Guidi in #89)

### Changed

- `redirect_to` now is a flow control method: it terminates the execution of an action, including the callbacks. (Alfonso Uceda Pompa in #73)

[0.4.0]: https://github.com/hanami/hanami-action/compare/v0.3.2...v0.4.0

## [0.3.2] - 2015-01-30

### Added

- Callbacks: introduced `append_before` (alias of `before`), `append_after` (alias of `after`), `prepend_before` and `prepend_after`. (Alfonso Uceda Pompa in #65)
- Introduced `Lotus::Action::Params#raw` which returns unfiltered data as it comes from an HTTP request. (Alfonso Uceda Pompa in #69)
- `Lotus::Action::Rack.use` now fully supports Rack middleware, by mounting an internal `Rack::Builder` instance. (Alfonso Uceda Pompa in #66)
- Introduced `Lotus::Action::Throwable#halt` now accepts an optional message. If missing it falls back to the corresponding HTTP status message. (Simone Carletti in #67)
- Nested params validation. (Steve Hodgkiss in #50)

### Fixed

- Ensure HEAD requests will return empty body. (Luca Guidi in #57)
- Ensure HTTP status codes with empty body won't send body and non-entity headers. (Stefano Verna in #18)
- Only dump exceptions in `rack.errors` if handling is turned off, or the raised exception is not managed. (Luca Guidi in #58)
- Ensure params will return coerced values. (Luca Guidi in #58)

[0.3.2]: https://github.com/hanami/hanami-action/compare/v0.3.1...v0.3.2

## [0.3.1] - 2015-01-08

### Added

- Introduced `Action#request` which returns an instance a `Rack::Request` compliant object: `Lotus::Action::Request`. (Lasse Skindstad Ebert in #48)

### Fixed

- Ensure params to return coerced values. (Steve Hodgkiss in #54)

[0.3.1]: https://github.com/hanami/hanami-action/compare/v0.3.0...v0.3.1

## [0.3.0] - 2014-12-23

### Added

- Introduced `Action#request_id` as unique identifier for an incoming HTTP request. (Luca Guidi)
- Introduced `Lotus::Controller.load!` as loading framework entry point. (Luca Guidi)
- Allow to define a default charset (`default_charset` configuration). (Kir Shatrov in #45)
- Automatic content type with charset (eg `Content-Type: text/html; charset=utf-8`). (Kir Shatrov in #45)
- Allow to specify custom exception handlers: procs or methods (`exception_handler` configuration). (Michał Krzyżanowski in #44)
- Introduced HTTP caching (`Cache-Control`, `Last-Modified`, ETAG, Conditional GET, expires). (Karl Freeman & Lucas Souza in #43)
- Introduced `Action::Params#to_h` and `#to_hash`. (Satoshi Amemiya in #42)
- Added `#params` and `#errors` as default exposures. (Luca Guidi)
- Introduced complete params validations. (Luca Guidi)
- Allow to whitelist params. (Luca Guidi & Matthew Bellantoni in #38)
- Allow to define custom classes for params via `Action.params`. (Luca Guidi & Matthew Bellantoni in #38)
- Introduced `Action#format` as query method to introspect the requested mime type. (Krzysztof Zalewski in #37)
- Official support for Ruby 2.2. (Luca Guidi)

### Changed

- Renamed `Configuration#modules` to `#prepare`. (Trung Lê in #41)
- Update HTTP status codes to IETF RFC 7231. (Luca Guidi)
- When `Lotus::Controller` is included, don't inject code. (Luca Guidi)
- Removed `Controller.action` as a DSL to define actions. (Luca Guidi)
- Removed `Action#content_type` in favor of `#format=` which accepts a symbol (eg. `:json`). (Krzysztof Zalewski in #37)
- Reduce method visibility where possible (Ruby `private` and `protected`). (Fuad Saud in #17)

### Fixed

- Don't let exposures definition to override existing methods. (Luca Guidi in #40)

[0.3.0]: https://github.com/hanami/hanami-action/compare/v0.2.0...v0.3.0

## [0.2.0] - 2014-06-23

### Added

- Introduced `Controller.configure` and `Controller.duplicate`. (Luca Guidi)
- Introduced `Action.use`, that let to use a Rack middleware as a before callback. (Luca Guidi)
- Allow to define a default mime type when the request is `Accept: */*` (`default_format` configuration). (Luca Guidi)
- Allow to register custom mime types and associate them to a symbol (`format` configuration). (Luca Guidi)
- Introduced `Configuration#handle_exceptions` to associate exceptions to HTTP statuses. (Luca Guidi)
- Allow developers to toggle exception handling (`handle_exceptions` configuration). (Damir Zekic in #23)
- Introduced `Controller::Configuration`. (Luca Guidi)
- Official support for Ruby 2.1. (Luca Guidi)

### Changed

- `Lotus::Action::Params` doesn't inherit from `Lotus::Utils::Hash` anymore. (Luca Guidi)
- `Lotus::Action::CookieJar` doesn't inherit from `Lotus::Utils::Hash` anymore. (Luca Guidi)
- Make HTTP status messages compliant with IANA and Rack. (Luca Guidi)
- Moved `#throw` override logic into `#halt`, which keeps the same semantic. (Damir Zekic in #28)

### Fixed

- Reference exception in `rack.errors`. (Krzysztof Zalewski in #26)

[0.2.0]: https://github.com/hanami/hanami-action/compare/v0.1.0...v0.2.0

## [0.1.0] - 2014-02-23

### Added

- Introduced `Action.accept` to whitelist accepted mime types. (Luca Guidi)
- Introduced `Action#accept?` as a query method for the current request. (Luca Guidi)
- Allow to whitelist handled exceptions and associate them to an HTTP status. (Luca Guidi)
- Automatic `Content-Type`. (Luca Guidi)
- Use `throw` as a control flow which understands HTTP status. (Luca Guidi)
- Introduced opt-in support for HTTP/Rack cookies. (Luca Guidi)
- Introduced opt-in support for HTTP/Rack sessions. (Luca Guidi)
- Introduced HTTP redirect API. (Luca Guidi)
- Introduced callbacks for actions: before and after. (Luca Guidi)
- Introduced exceptions handling with HTTP statuses. (Luca Guidi)
- Introduced exposures. (Luca Guidi)
- Introduced basic actions compatible with Rack. (Luca Guidi)
- Official support for Ruby 2.0. (Luca Guidi)

[0.1.0]: https://github.com/hanami/hanami-action/releases/tag/v0.1.0
