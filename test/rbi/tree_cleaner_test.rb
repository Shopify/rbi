# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class TreeCleanerTest < Minitest::Test
      include TestHelper
      extend T::Sig

      def test_do_nothing_with_empty_index
        index = Tapioca::RBI::Index.new

        shim = <<~RBI
          class Foo
            attr_reader :foo
          end

          module Bar
            def bar; end
          end

          BAZ = 42
        RBI

        original = Tapioca::RBI::Parser.parse_string(shim)
        cleaned, operations = TreeCleaner.clean(original, index)

        assert_equal(shim, cleaned.string)
        assert_empty(operations)
      end

      def test_clean_all_definitions
        tree1 = Tapioca::RBI::Parser.parse_string(<<~RBI)
          class Foo
            attr_reader :foo
          end
        RBI

        tree2 = Tapioca::RBI::Parser.parse_string(<<~RBI)
          module Bar
            def bar; end
          end
        RBI

        tree3 = Tapioca::RBI::Parser.parse_string(<<~RBI)
          BAZ = 42
        RBI

        index = Tapioca::RBI::Index.index(tree1, tree2, tree3)

        shim = Tapioca::RBI::Parser.parse_string(<<~RBI)
          class Foo
            attr_reader :foo
          end

          module Bar
            def bar; end
          end

          BAZ = 42
        RBI

        cleaned, operations = TreeCleaner.clean(shim, index)

        assert(cleaned.empty?)

        assert_equal(<<~RES.rstrip, operations.join("\n"))
          Deleted .attr_reader(:foo) duplicate from -:2:2-2:18
          Deleted ::Foo duplicate from -:1:0-3:3
          Deleted #bar() duplicate from -:2:2-2:14
          Deleted ::Bar duplicate from -:1:0-3:3
          Deleted ::BAZ duplicate from -:1:0-1:8
        RES
      end

      def test_clean_empty_scopes
        tree1 = Tapioca::RBI::Parser.parse_string(<<~RBI)
          class Foo
            attr_reader :foo
          end
        RBI

        tree2 = Tapioca::RBI::Parser.parse_string(<<~RBI)
          class Foo
            def bar; end
          end
        RBI

        tree3 = Tapioca::RBI::Parser.parse_string(<<~RBI)
          Foo::BAZ = 42
        RBI

        index = Tapioca::RBI::Index.index(tree1, tree2, tree3)

        shim = Tapioca::RBI::Parser.parse_string(<<~RBI)
          class Foo
            attr_reader :foo
            def bar; end
            BAZ = 42
          end
        RBI

        cleaned, operations = TreeCleaner.clean(shim, index)

        assert(cleaned.empty?)

        assert_equal(<<~RES.rstrip, operations.join("\n"))
          Deleted .attr_reader(:foo) duplicate from -:2:2-2:18
          Deleted #bar() duplicate from -:2:2-2:14
          Deleted ::BAZ duplicate from -:1:0-1:13
          Deleted ::Foo duplicate from -:1:0-3:3
        RES
      end
    end
  end
end
