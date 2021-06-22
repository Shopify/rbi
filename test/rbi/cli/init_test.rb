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

      project.write("index_mock.json", <<~JSON)
        {
          "foo@1.0.0": "FOO = 1",
          "bar@2.0.0": "BAR = 2"
        }
      JSON

      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        out, err, status = project.bundle_exec("rbi init --no-netrc --mock-fetcher-file index_mock.json --no-color")
        assert(status)
        assert_empty(out)
        assert_log(<<~OUT, err)
          Success: Pulled `bar@2.0.0.rbi` from central repository
          Success: Pulled `foo@1.0.0.rbi` from central repository
        OUT
      end

      assert_equal("FOO = 1", File.read("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi").strip)
      assert_equal("BAR = 2", File.read("#{project.path}/sorbet/rbi/gems/bar@2.0.0.rbi").strip)

      project.destroy
    end
  end
end