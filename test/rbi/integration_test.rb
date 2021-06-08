# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class IntegrationTest < Minitest::Test
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

    def test_update_generating_missing_rbis
      project = self.project("test_update_generating_missing_rbis")

      project.write("vendor/cache/foo.gemspec", <<~FOO)
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

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
        gem "tapioca"
        gem "foo", path: "vendor/cache"
      GEMFILE

      project.write("central_repo/index.json", "{}")

      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        project.run("bundle exec tapioca generate --exclude foo")
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))

        _, err, status = project.run("bundle exec rbi update --mock-github-client -v --no-color")
        assert(status)
        assert_log(<<~OUT, T.must(err))
          Info: Generating RBIs that were missing in the central repository using tapioca
          Debug: Requiring all gems to prepare for compiling...  Done

          Processing 'foo' gem:
            Compiling foo, this may take a few seconds...   Done (empty output)

          All operations performed in working directory.
          Please review changes and commit them.

          Success: Gem RBIs successfully updated
        OUT
      end
      assert(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))

      project.destroy
    end

    def test_generate_public_gem
      project = self.project("test_generate_gem")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
        gem "tapioca"
      GEMFILE

      gem_input = "parser@2.3.1.2"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.path}/#{gem_input}.rbi"))

        _, err, status = project.run("bundle exec rbi generate #{gem_input} --no-color")
        assert(status)
        assert_log(<<~OUT, T.must(err))
          Success: Generated `parser@2.3.1.2.rbi`
        OUT
      end
      assert(File.file?("#{project.path}/#{gem_input}.rbi"))

      project.destroy
    end

    def test_generate_cloudsmith_gem
      skip("Requires authentication to cloudsmith on CI")
      project = self.project("test_generate_cloudsmith_gem")

      project.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        gem "rbi", path: "#{File.expand_path(Bundler.root)}"
        gem "tapioca"
      GEMFILE

      gem_input = "softer_delete@0.2.2"
      Bundler.with_unbundled_env do
        project.run("bundle config set --local path 'vendor/bundle'")
        project.run("bundle install")
        refute(File.file?("#{project.path}/#{gem_input}.rbi"))

        _, err, status = project.run("bundle exec rbi generate #{gem_input} --cloudsmith-source --no-color")
        assert(status)
        assert_log(<<~OUT, T.must(err))
          Success: Generated `softer_delete@0.2.2.rbi`
        OUT
      end
      assert(File.file?("#{project.path}/#{gem_input}.rbi"))

      project.destroy
    end
  end
end
