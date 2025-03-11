# typed: strict
# frozen_string_literal: true

require_relative "lib/rbi/version"

Gem::Specification.new do |spec|
  spec.name          = "rbi"
  spec.version       = RBI::VERSION
  spec.authors       = ["Alexandre Terrasa"]
  spec.email         = ["ruby@shopify.com"]

  spec.summary       = "RBI generation framework"
  spec.homepage      = "https://github.com/Shopify/rbi"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.require_paths = ["lib"]

  spec.files         = Dir.glob("lib/**/*.rb") + Dir.glob("rbi/**/*.rbi") + [
    "README.md",
    "Gemfile",
    "Rakefile",
    "rbi/rbi.rbi",
  ]

  spec.add_dependency("prism", "~> 1.0")
  spec.add_dependency("rbs", ">= 3.4.4")
  spec.add_dependency("sorbet-runtime", ">= 0.5.9204")

  spec.required_ruby_version = ">= 3.1"
end
