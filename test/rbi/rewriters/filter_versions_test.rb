# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FilterVersions < Minitest::Test
    def test_filter_versions_do_nothing
      rbi = <<~RBI
        class Foo; end
        class Bar; end
        class Baz; end
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(rbi, tree.string)
    end

    def test_filter_versions_less_than
      rbi = <<~RBI
        # @version < 1.0.0
        class Foo; end

        # @version < 0.4.0-prerelease
        class Bar; end

        # @version < 0.4.0
        class Baz; end

        # @version < 0.3.0
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version < 1.0.0
        class Foo; end
      RBI
    end

    def test_filter_versions_greater_than
      rbi = <<~RBI
        # @version > 1.0.0
        class Foo; end

        # @version > 0.4.0-prerelease
        class Bar; end

        # @version > 0.4.0
        class Baz; end

        # @version > 0.3.0
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version > 0.4.0-prerelease
        class Bar; end

        # @version > 0.3.0
        class Buzz; end
      RBI
    end

    def test_filter_versions_equals
      rbi = <<~RBI
        # @version = 1.0.0
        class Foo; end

        # @version = 0.4.0-prerelease
        class Bar; end

        # @version = 0.4.0
        class Baz; end

        # @version = 0.3.0
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version = 0.4.0
        class Baz; end
      RBI
    end

    def test_filter_versions_not_equal
      rbi = <<~RBI
        # @version != 1.0.0
        class Foo; end

        # @version != 0.4.0-prerelease
        class Bar; end

        # @version != 0.4.0
        class Baz; end

        # @version != 0.3.0
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version != 1.0.0
        class Foo; end

        # @version != 0.4.0-prerelease
        class Bar; end

        # @version != 0.3.0
        class Buzz; end
      RBI
    end

    def test_filter_versions_twiddle_wakka
      rbi = <<~RBI
        # @version ~> 1.1.0
        class Foo; end

        # @version ~> 2.0
        class Bar; end

        # @version ~> 3
        class Baz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("1.1.5"))
      assert_equal(<<~RBI, tree.string)
        # @version ~> 1.1.0
        class Foo; end
      RBI
    end

    def test_filter_versions_greater_than_or_equals
      rbi = <<~RBI
        # @version >= 1.0.0
        class Foo; end

        # @version >= 0.4.0-prerelease
        class Bar; end

        # @version >= 0.4.0
        class Baz; end

        # @version >= 0.3.0
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version >= 0.4.0-prerelease
        class Bar; end

        # @version >= 0.4.0
        class Baz; end

        # @version >= 0.3.0
        class Buzz; end
      RBI
    end

    def test_filter_versions_less_than_or_equals
      rbi = <<~RBI
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0-prerelease
        class Bar; end

        # @version <= 0.4.0
        class Baz; end

        # @version <= 0.3.0
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0
        class Baz; end
      RBI
    end

    def test_filter_versions_prerelease
      rbi = <<~RBI
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0-prerelease
        class Bar; end

        # @version = 0.4.0
        class Baz; end

        # @version >= 0.4.0-prerelease
        class Buzz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0-prerelease"))
      assert_equal(<<~RBI, tree.string)
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0-prerelease
        class Bar; end

        # @version >= 0.4.0-prerelease
        class Buzz; end
      RBI
    end

    def test_filter_versions_and
      rbi = <<~RBI
        # @version > 0.3.0, < 1.0.0
        class Foo; end

        # @version >= 1.1.0, < 2.0.0
        class Bar; end

        # @version > 0.3.2, <= 0.4.2
        class Baz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version > 0.3.0, < 1.0.0
        class Foo; end

        # @version > 0.3.2, <= 0.4.2
        class Baz; end
      RBI
    end

    def test_filter_versions_or
      rbi = <<~RBI
        # @version < 0.3.0
        # @version > 1.0.0
        class Foo; end

        # @version = 0.4.0
        # @version > 0.5.0
        class Bar; end

        # @version < 0.3.2
        # @version = 0.4.0-prerelease
        # @version > 0.4.0
        class Baz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version = 0.4.0
        # @version > 0.5.0
        class Bar; end
      RBI
    end

    def test_filter_versions_andor
      rbi = <<~RBI
        # @version > 0.3.0, < 1.0.0
        # @version > 1.5.0
        class Foo; end

        # @version >= 0.1.0, < 0.2.3
        # @version = 0.4.0
        class Bar; end

        # @version > 0.2.5, < 0.2.7
        # @version > 0.4.0, < 0.5.0
        class Baz; end
      RBI

      tree = Parser.parse_string(rbi)

      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      assert_equal(<<~RBI, tree.string)
        # @version > 0.3.0, < 1.0.0
        # @version > 1.5.0
        class Foo; end

        # @version >= 0.1.0, < 0.2.3
        # @version = 0.4.0
        class Bar; end
      RBI
    end

    def test_filter_versions_parse_errors
      rbi = <<~RBI
        # @version >
        class Foo; end
      RBI

      tree = Parser.parse_string(rbi)

      assert_raises(Gem::Requirement::BadRequirementError) do
        Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))
      end
    end
  end
end
