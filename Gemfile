# frozen_string_literal: true

source "http://rubygems.org"

gemspec

eval_gemfile "Gemfile.devtools"

unless ENV["CI"]
  gem "byebug", platforms: :mri
  gem "yard"
  gem "yard-junk"
end

if ENV["RACK_MATRIX_VALUE"]
  gem "rack", ENV["RACK_MATRIX_VALUE"]
end

gem "hanami-utils", github: "hanami/utils", branch: "main"

group :validations do
  gem "dry-validation", github: "dry-rb/dry-validation", branch: "main"
end

group :test do
  gem "dry-files", github: "dry-rb/dry-files", branch: "main"
  gem "hanami-router", github: "hanami/router", branch: "main"
  gem "hanami-cli", github: "hanami/cli", branch: "main"
  gem "hanami-view", github: "hanami/view", branch: "main"
  gem "hanami", github: "hanami/hanami", branch: "main"
  gem "rack-test", "~> 2.0"
  gem "rspec", "~> 3.9"
  gem "slim"
end

group :benchmarks do
  gem "benchmark-memory"
  gem "memory_profiler"
end

gem "hanami-devtools", github: "hanami/devtools", branch: "main"
