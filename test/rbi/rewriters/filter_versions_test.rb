# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FilterVersions < Minitest::Test
    include TestHelper

    def test_filter_versions_do_nothing
      rbi = <<~RBI
        class Foo; end
        class Bar; end
        class Baz; end
        class Buzz; end
      RBI

      tree = parse_rbi(rbi)
      Rewriters::FilterVersions.filter(tree, Gem::Version.new("0.4.0"))

      assert_equal(rbi, tree.string)
    end

    def test_filter_versions_less_than
      tree = parse_rbi(<<~RBI)
        # @version < 1.0.0
        class Foo; end

        # @version < 0.4.0-prerelease
        class Bar; end

        # @version < 0.4.0
        class Baz; end

        # @version < 0.3.0
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

      assert_equal(<<~RBI, tree.string)
        # @version < 1.0.0
        class Foo; end
      RBI
    end

    def test_filter_versions_greater_than
      tree = parse_rbi(<<~RBI)
        # @version > 1.0.0
        class Foo; end

        # @version > 0.4.0-prerelease
        class Bar; end

        # @version > 0.4.0
        class Baz; end

        # @version > 0.3.0
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

      assert_equal(<<~RBI, tree.string)
        # @version > 0.4.0-prerelease
        class Bar; end

        # @version > 0.3.0
        class Buzz; end
      RBI
    end

    def test_filter_versions_equals
      tree = parse_rbi(<<~RBI)
        # @version = 1.0.0
        class Foo; end

        # @version = 0.4.0-prerelease
        class Bar; end

        # @version = 0.4.0
        class Baz; end

        # @version = 0.3.0
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

      assert_equal(<<~RBI, tree.string)
        # @version = 0.4.0
        class Baz; end
      RBI
    end

    def test_filter_versions_not_equal
      tree = parse_rbi(<<~RBI)
        # @version != 1.0.0
        class Foo; end

        # @version != 0.4.0-prerelease
        class Bar; end

        # @version != 0.4.0
        class Baz; end

        # @version != 0.3.0
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

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
      tree = parse_rbi(<<~RBI)
        # @version ~> 1.1.0
        class Foo; end

        # @version ~> 2.0
        class Bar; end

        # @version ~> 3
        class Baz; end
      RBI

      tree.filter_versions!(Gem::Version.new("1.1.5"))

      assert_equal(<<~RBI, tree.string)
        # @version ~> 1.1.0
        class Foo; end
      RBI
    end

    def test_filter_versions_greater_than_or_equals
      tree = parse_rbi(<<~RBI)
        # @version >= 1.0.0
        class Foo; end

        # @version >= 0.4.0-prerelease
        class Bar; end

        # @version >= 0.4.0
        class Baz; end

        # @version >= 0.3.0
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

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
      tree = parse_rbi(<<~RBI)
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0-prerelease
        class Bar; end

        # @version <= 0.4.0
        class Baz; end

        # @version <= 0.3.0
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

      assert_equal(<<~RBI, tree.string)
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0
        class Baz; end
      RBI
    end

    def test_filter_versions_prerelease
      tree = parse_rbi(<<~RBI)
        # @version <= 1.0.0
        class Foo; end

        # @version <= 0.4.0-prerelease
        class Bar; end

        # @version = 0.4.0
        class Baz; end

        # @version >= 0.4.0-prerelease
        class Buzz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0-prerelease"))

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
      tree = parse_rbi(<<~RBI)
        # @version > 0.3.0, < 1.0.0
        class Foo; end

        # @version >= 1.1.0, < 2.0.0
        class Bar; end

        # @version > 0.3.2, <= 0.4.2
        class Baz; end
      RBI

      tree.filter_versions!(Gem::Version.new("0.4.0"))

      assert_equal(<<~RBI, tree.string)
        # @version > 0.3.0, < 1.0.0
        class Foo; end

        # @version > 0.3.2, <= 0.4.2
        class Baz; end
      RBI
    end

    def test_filter_versions_or
      tree = parse_rbi(<<~RBI)
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

      tree.filter_versions!(Gem::Version.new("0.4.0"))

      assert_equal(<<~RBI, tree.string)
        # @version = 0.4.0
        # @version > 0.5.0
        class Bar; end
      RBI
    end

    def test_filter_versions_andor
      tree = parse_rbi(<<~RBI)
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

      tree.filter_versions!(Gem::Version.new("0.4.0"))

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
      tree = parse_rbi(<<~RBI)
        # @version >
        class Foo; end
      RBI

      assert_raises(Gem::Requirement::BadRequirementError) do
        tree.filter_versions!(Gem::Version.new("0.4.0"))
      end
    end
  end
end
