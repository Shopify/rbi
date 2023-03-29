# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class LintVersions < Minitest::Test
    def test_lint_versions_do_nothing
      tree = Parser.parse_string(<<~RBI)
        class Foo; end
      RBI

      Rewriters::LintVersions.new.visit(tree)
    end

    def test_lint_versions_does_not_raise_on_valid_version
      tree = Parser.parse_string(<<~RBI)
        # @version < 1.0.0-prerelease
        class Foo; end
      RBI

      Rewriters::LintVersions.new.visit(tree)
    end

    def test_lint_versions_raises_on_invalid_version
      tree = Parser.parse_string(<<~RBI)
        # @version < abc
        class Foo; end
      RBI

      err = assert_raises(Rewriters::LintVersions::InvalidVersion) do
        Rewriters::LintVersions.new.visit(tree)
      end

      assert_equal("-:1:0-1:16", err.location.to_s)
    end

    def test_lint_versions_raises_on_invalid_operator
      tree = Parser.parse_string(<<~RBI)
        # @version ~> 1.0.0
        class Foo; end
      RBI

      err = assert_raises(Rewriters::LintVersions::InvalidVersion) do
        Rewriters::LintVersions.new.visit(tree)
      end

      assert_equal("-:1:0-1:19", err.location.to_s)
    end

    def test_lint_versions_raises_on_empty_version
      tree = Parser.parse_string(<<~RBI)
        # @version
        class Foo; end
      RBI

      err = assert_raises(Rewriters::LintVersions::InvalidVersion) do
        Rewriters::LintVersions.new.visit(tree)
      end

      assert_equal("-:1:0-1:10", err.location.to_s)
    end

    def test_lint_versions_ignore_invalid_annotation
      tree = Parser.parse_string(<<~RBI)
        # @version-invalid < 1.0.0
        # @version_invalid < 1.0.0
        # @versioninvalid < 1.0.0
        class Foo; end
      RBI

      Rewriters::LintVersions.new.visit(tree)
    end
  end
end
