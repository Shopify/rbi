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

  spec.files         = Dir.glob("lib/**/*.rb") + [
    "README.md",
    "Gemfile",
    "Rakefile",
  ]

  spec.executables   = Dir.glob("exe/*").map { |f| File.basename(f) }
  spec.bindir        = "exe"

  spec.add_dependency("prism", ">= 0.18.0", "< 1.0.0")
  spec.add_dependency("sorbet-runtime", ">= 0.5.9204")

  spec.required_ruby_version = ">= 3.1"
end
