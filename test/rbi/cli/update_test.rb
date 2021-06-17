# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class UpdateTest < Minitest::Test
    include TestHelper

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
        assert_log(<<~OUT, err)
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
  end
end
