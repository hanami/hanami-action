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

gem "hanami-utils", "~> 2.3"

group :validations do
  gem "hanami-validations", "~> 2.3"
end

group :test do
  gem "dry-files", "~> 1.1"
  gem "hanami-router", "~> 2.3"
  gem "hanami-cli", "~> 2.3"
  gem "hanami-view", "~> 2.3"
  gem "hanami", "~> 2.3"
  gem "rack-test", "~> 2.0"
  gem "rspec", "~> 3.9"
  gem "slim"
end

group :benchmarks do
  gem "benchmark-memory"
  gem "memory_profiler"
end

gem "hanami-devtools", github: "hanami/devtools", branch: "main"
