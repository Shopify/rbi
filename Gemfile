# typed: true
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group(:development, :test) do
  gem("byebug")
  gem("minitest")
  gem("rubocop", "~> 1.7", require: false)
  gem("rubocop-shopify", require: false)
  gem("rubocop-sorbet", require: false)
  gem("sorbet", require: false)
  gem("tapioca", require: false, github: "Shopify/tapioca", branch: "master")
end
