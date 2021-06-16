# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class InitTest < Minitest::Test
    include TestHelper

    def test_init
      project = self.project("test_init")

      project.write("gems/foo/foo.gemspec", <<~FOO)
        Gem::Specification.new do |spec|
          spec.name          = "foo"
          spec.version       = "1.0.0"
          spec.authors       = ["Test User"]
          spec.email         = ["test@example.com"]

          spec.summary       = "Foo - Test Gem"
          spec.homepage      = "https://example.com/foo"
          spec.license       = "MIT"

          spec.metadata["allowed_push_host"] = "no"

          spec.require_paths = ["lib"]

          spec.files         = Dir.glob("lib/**/*.rb")
        end
      FOO

      project.write("gems/bar/bar.gemspec", <<~FOO)
        Gem::Specification.new do |spec|
          spec.name          = "bar"
          spec.version       = "2.0.0"
          spec.authors       = ["Test User"]
          spec.email         = ["test@example.com"]

          spec.summary       = "Bar - Test Gem"
          spec.homepage      = "https://example.com/bar"
          spec.license       = "MIT"

          spec.metadata["allowed_push_host"] = "no"

          spec.require_paths = ["lib"]

          spec.files         = Dir.glob("lib/**/*.rb")
        end
      FOO

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
        gem "foo", path: "gems/foo"
        gem "bar", path: "gems/bar"
      GEMFILE

      project.write("central_repo/index.json", <<~JSON)
        {
          "foo": {
            "1.0.0": "foo@1.0.0.rbi"
          },
          "bar": {
            "2.0.0": "bar@2.0.0.rbi"
          }
        }
      JSON

      project.write("central_repo/foo@1.0.0.rbi", <<~RBI)
        FOO = 1
      RBI

      project.write("central_repo/bar@2.0.0.rbi", <<~RBI)
        BAR = 2
      RBI

      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        _, _, status = project.run("bundle exec rbi init --mock-github-client")
        assert(status)
      end

      assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi").strip)
      assert_equal("BAR = 2", File.read("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi").strip)

      project.destroy
    end
  end
end
