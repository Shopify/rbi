# typed: true
# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rbi.gemspec
gemspec

gem("rake", "~> 13.0")
gem("sorbet-runtime")
gem("thor")

group(:development, :test) do
  gem("minitest")
  gem("rubocop", "~> 1.7", require: false)
  gem("rubocop-shopify", require: false)
  gem("rubocop-sorbet", require: false)
  gem("sorbet", require: false)
  gem("tapioca", require: false)
end
