# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class RemoveKnownDefinitionsTest < Minitest::Test
    def test_remove_known_definitions_does_nothing_with_an_empty_index
      index = Index.new

      shim = <<~RBI
        class Foo
          attr_reader :foo
        end

        module Bar
          def bar; end
        end

        BAZ = 42
      RBI

      original = Parser.parse_string(shim)
      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(original, index)

      assert_equal(shim, cleaned.string)
      assert_empty(operations)
    end

    def test_remove_known_definitions_removes_all_definitions_found_in_index
      tree1 = Parser.parse_string(<<~RBI)
        class Foo
          attr_reader :foo
        end
      RBI

      tree2 = Parser.parse_string(<<~RBI)
        module Bar
          def bar; end
        end
      RBI

      tree3 = Parser.parse_string(<<~RBI)
        BAZ = 42
      RBI

      index = Index.index(tree1, tree2, tree3)

      shim = Parser.parse_string(<<~RBI)
        class Foo
          attr_reader :foo
        end

        module Bar
          def bar; end
        end

        BAZ = 42
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert(cleaned.empty?)

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo.attr_reader(:foo) at -:2:2-2:18 (duplicate from -:2:2-2:18)
        Deleted ::Foo at -:1:0-3:3 (duplicate from -:1:0-3:3)
        Deleted ::Bar#bar() at -:6:2-6:14 (duplicate from -:2:2-2:14)
        Deleted ::Bar at -:5:0-7:3 (duplicate from -:1:0-3:3)
        Deleted ::BAZ at -:9:0-9:8 (duplicate from -:1:0-1:8)
      RES
    end

    def test_remove_known_definitions_keeps_definitions_not_found_in_index
      tree = Parser.parse_string(<<~RBI)
        class Foo
          def foo; end
          FOO = 42
        end
      RBI

      index = Index.index(tree)

      shim = Parser.parse_string(<<~RBI)
        class Foo
          def foo; end
          def bar; end
          FOO = 42
          BAR = 42
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_equal(<<~RBI, cleaned.string)
        class Foo
          def bar; end
          BAR = 42
        end
      RBI

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo#foo() at -:2:2-2:14 (duplicate from -:2:2-2:14)
        Deleted ::Foo::FOO at -:4:2-4:10 (duplicate from -:3:2-3:10)
      RES
    end

    def test_remove_known_definitions_removes_empty_scopes
      tree1 = Parser.parse_string(<<~RBI)
        class Foo
          attr_reader :foo
        end
      RBI

      tree2 = Parser.parse_string(<<~RBI)
        class Foo
          def bar; end
        end
      RBI

      tree3 = Parser.parse_string(<<~RBI)
        Foo::BAZ = 42
      RBI

      index = Index.index(tree1, tree2, tree3)

      shim = Parser.parse_string(<<~RBI)
        class Foo
          attr_reader :foo
          def bar; end
          BAZ = 42
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert(cleaned.empty?)

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo.attr_reader(:foo) at -:2:2-2:18 (duplicate from -:2:2-2:18)
        Deleted ::Foo#bar() at -:3:2-3:14 (duplicate from -:2:2-2:14)
        Deleted ::Foo::BAZ at -:4:2-4:10 (duplicate from -:1:0-1:13)
        Deleted ::Foo at -:1:0-5:3 (duplicate from -:1:0-3:3)
      RES
    end

    def test_remove_known_definitions_keeps_empty_scopes_not_found_in_index
      tree1 = Parser.parse_string(<<~RBI)
        class Foo; end
      RBI

      tree2 = Parser.parse_string(<<~RBI)
        class Bar
          def bar; end
        end
      RBI

      index = Index.index(tree1, tree2)

      shim = Parser.parse_string(<<~RBI)
        class Foo; end
        class Bar
          def bar; end
        end
        class Baz; end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_equal(<<~RBI, cleaned.string)
        class Baz; end
      RBI

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo at -:1:0-1:14 (duplicate from -:1:0-1:14)
        Deleted ::Bar#bar() at -:3:2-3:14 (duplicate from -:2:2-2:14)
        Deleted ::Bar at -:2:0-4:3 (duplicate from -:1:0-3:3)
      RES
    end
  end
end
