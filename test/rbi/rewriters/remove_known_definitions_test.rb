# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class RemoveKnownDefinitionsTest < Minitest::Test
    include TestHelper

    def test_remove_known_definitions_does_nothing_with_an_empty_index
      index = Index.new

      shim = <<~RBI
        class Foo
          attr_reader :foo
        end

        module Bar
          def bar; end
        end

        BAZ = T.let(T.unsafe(nil), T.untyped)
      RBI

      original = parse_rbi(shim)
      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(original, index)

      assert_equal(shim, cleaned.string)
      assert_empty(operations)
    end

    def test_remove_known_definitions_removes_all_definitions_found_in_index
      tree1 = parse_rbi(<<~RBI)
        class Foo
          attr_reader :foo
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Bar
          def bar; end
        end
      RBI

      tree3 = parse_rbi(<<~RBI)
        BAZ = 42
      RBI

      index = Index.index(tree1, tree2, tree3)

      shim = parse_rbi(<<~RBI)
        class Foo
          attr_reader :foo
        end

        module Bar
          def bar; end
        end

        BAZ = 42
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_empty(cleaned)

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo.attr_reader(:foo) at -:2:2-2:18 (duplicate from -:2:2-2:18)
        Deleted ::Foo at -:1:0-3:3 (duplicate from -:1:0-3:3)
        Deleted ::Bar#bar() at -:6:2-6:14 (duplicate from -:2:2-2:14)
        Deleted ::Bar at -:5:0-7:3 (duplicate from -:1:0-3:3)
        Deleted ::BAZ at -:9:0-9:8 (duplicate from -:1:0-1:8)
      RES
    end

    def test_remove_known_definitions_keeps_definitions_not_found_in_index
      tree = parse_rbi(<<~RBI)
        class Foo
          def foo; end
          FOO = 42
        end
      RBI

      index = Index.index(tree)

      shim = parse_rbi(<<~RBI)
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
          BAR = T.let(T.unsafe(nil), T.untyped)
        end
      RBI

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo#foo() at -:2:2-2:14 (duplicate from -:2:2-2:14)
        Deleted ::Foo::FOO at -:4:2-4:10 (duplicate from -:3:2-3:10)
      RES
    end

    def test_remove_known_definitions_keeps_mismatching_definitions
      tree = parse_rbi(<<~RBI)
        class Foo
          def foo; end
        end

        class Bar
          def foo; end
        end

        def foo; end
        attr_writer :bar
      RBI

      index = Index.index(tree)

      shim = parse_rbi(<<~RBI)
        class Foo
          def foo(x); end
        end

        module Bar; end

        attr_reader :foo
        attr_reader :bar
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_equal(shim.string, cleaned.string)
      assert_empty(operations)
    end

    def test_remove_known_definitions_removes_empty_scopes
      tree1 = parse_rbi(<<~RBI)
        class Foo
          attr_reader :foo
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class Foo
          def bar; end
        end
      RBI

      tree3 = parse_rbi(<<~RBI)
        Foo::BAZ = 42
      RBI

      index = Index.index(tree1, tree2, tree3)

      shim = parse_rbi(<<~RBI)
        class Foo
          attr_reader :foo
          def bar; end
          BAZ = 42
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_empty(cleaned)

      assert_equal(<<~RES.rstrip, operations.join("\n"))
        Deleted ::Foo.attr_reader(:foo) at -:2:2-2:18 (duplicate from -:2:2-2:18)
        Deleted ::Foo#bar() at -:3:2-3:14 (duplicate from -:2:2-2:14)
        Deleted ::Foo::BAZ at -:4:2-4:10 (duplicate from -:1:0-1:13)
        Deleted ::Foo at -:1:0-5:3 (duplicate from -:1:0-3:3)
      RES
    end

    def test_remove_known_definitions_keeps_empty_scopes_not_found_in_index
      tree1 = parse_rbi(<<~RBI)
        class Foo; end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class Bar
          def bar; end
        end
      RBI

      index = Index.index(tree1, tree2)

      shim = parse_rbi(<<~RBI)
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

    def test_remove_known_definitions_keeps_nodes_defined_with_a_signature
      tree = parse_rbi(<<~RBI)
        class Foo
          def foo; end
          def self.bar; end
          attr_reader :baz
        end
      RBI

      index = Index.index(tree)

      shim = parse_rbi(<<~RBI)
        class Foo
          sig { void }
          def foo; end

          sig { void }
          def self.bar; end

          sig { returns(String) }
          attr_reader :baz
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_equal(shim.string, cleaned.string)
      assert_empty(operations)
    end

    def test_remove_known_definitions_keeps_multiple_attributes
      tree = parse_rbi(<<~RBI)
        class Foo
          attr_reader :foo
        end
      RBI

      index = Index.index(tree)

      shim = parse_rbi(<<~RBI)
        class Foo
          attr_reader :foo, :bar
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_equal(shim.string, cleaned.string)
      assert_empty(operations)
    end

    def test_remove_known_definitions_even_if_the_comments_differ
      tree = parse_rbi(<<~RBI)
        class Foo
          def foo; end
        end
      RBI

      index = Index.index(tree)

      shim = parse_rbi(<<~RBI)
        class Foo
          # Some comments
          def foo; end
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_empty(cleaned)

      assert_equal(<<~OUT.rstrip, operations.join("\n"))
        Deleted ::Foo#foo() at -:3:2-3:14 (duplicate from -:2:2-2:14)
        Deleted ::Foo at -:1:0-4:3 (duplicate from -:1:0-3:3)
      OUT
    end

    def test_remove_known_definitions_even_if_the_value_differ
      tree = parse_rbi(<<~RBI)
        class Foo
          FOO = 42
        end
      RBI

      index = Index.index(tree)

      shim = parse_rbi(<<~RBI)
        class Foo
          FOO = 24
        end
      RBI

      cleaned, operations = Rewriters::RemoveKnownDefinitions.remove(shim, index)

      assert_empty(cleaned)

      assert_equal(<<~OUT.rstrip, operations.join("\n"))
        Deleted ::Foo::FOO at -:2:2-2:10 (duplicate from -:2:2-2:10)
        Deleted ::Foo at -:1:0-3:3 (duplicate from -:1:0-3:3)
      OUT
    end
  end
end
