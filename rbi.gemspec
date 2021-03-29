# frozen_string_literal: true

require_relative "lib/rbi/version"

Gem::Specification.new do |spec|
  spec.name          = "rbi"
  spec.version       = Rbi::VERSION
  spec.authors       = ["Alexandre Terrasa, Kaan Ozkan"]
  spec.email         = ["alexandre.terrasa@shopify.com", "kaan.ozkan@shopify.com"]

  spec.summary       = "CLI tool to cleanup RBIs and interact with central RBI repository"
  spec.homepage      = "https://github.com/Shopify/rbi"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.bindir        = "exe"
  spec.executables   = %w(rbi)
  spec.require_paths = ["lib"]

  spec.files         = Dir.glob("lib/**/*.rb") + %w(
    README.md
    Gemfile
    Rakefile
  )
end
