# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rbi.gemspec
gemspec

gem("rake", "~> 13.0")
gem("sorbet-runtime")

group(:development, :test) do
  gem("rspec", "~> 3.0")
  gem("rubocop", "~> 1.7", require: false)
  gem("sorbet", require: false)
  gem("tapioca", require: false)
end
