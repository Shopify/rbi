# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Remove all definitions existing in the index from the current tree
    #
    # Let's create an `Index` from two different `Tree`s:
    # ~~~rb
    # tree1 = Parse.parse_string(<<~RBI)
    #   class Foo
    #     def foo; end
    #   end
    # RBI
    #
    # tree2 = Parse.parse_string(<<~RBI)
    #   FOO = 10
    # RBI
    #
    # index = Index.index(tree1, tree2)
    # ~~~
    #
    # We can use `RemoveKnownDefinitions` to remove the definitions found in the `index` from the `Tree` to clean:
    # ~~~rb
    # tree_to_clean = Parser.parse_string(<<~RBI)
    #   class Foo
    #     def foo; end
    #     def bar; end
    #   end
    #   FOO = 10
    #   BAR = 42
    # RBI
    #
    # cleaned_tree, operations = RemoveKnownDefinitions.remove(tree_to_clean, index)
    #
    # assert_equal(<<~RBI, cleaned_tree)
    #   class Foo
    #     def bar; end
    #   end
    #   BAR = 42
    # RBI
    #
    # assert_equal(<<~OPERATIONS, operations.join("\n"))
    #   Deleted ::Foo#foo at -:2:2-2-16 (duplicate from -:2:2-2:16)
    #   Deleted ::FOO at -:5:0-5:8 (duplicate from -:1:0-1:8)
    # OPERATIONS
    # ~~~
    class RemoveKnownDefinitions < Visitor
      sig { returns(Array[Operation]) }
      attr_reader :operations

      sig { params(index: Index).void }
      def initialize(index); end

      class << self
        sig { params(tree: Tree, index: Index).returns([Tree, Array[Operation]]) }
        def remove(tree, index); end
      end

      sig { params(nodes: Array[Node]).void }
      def visit_all(nodes); end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: Indexable).returns(T.nilable(Node)) }
      def previous_definition_for(node); end

      sig { params(node: Node, previous: Node).returns(T::Boolean) }
      def can_delete_node?(node, previous); end

      sig { params(node: Node, previous: Node).void }
      def delete_node(node, previous); end

      class Operation < T::Struct
        const :deleted_node, Node
        const :duplicate_of, Node

        sig { returns(String) }
        def to_s; end
      end
    end
  end
end
