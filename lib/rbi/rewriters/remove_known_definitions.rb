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
      extend T::Sig

      sig do
        params(
          tree: RBI::Tree,
          index: RBI::Index
        ).returns([RBI::Tree, T::Array[Operation]])
      end
      def self.remove(tree, index)
        v = RemoveKnownDefinitions.new(index)
        v.visit(tree)
        [tree, v.operations]
      end

      sig { returns(T::Array[Operation]) }
      attr_reader :operations

      sig { params(index: RBI::Index).void }
      def initialize(index)
        super()
        @index = index
        @operations = T.let([], T::Array[Operation])
      end

      sig { params(nodes: T::Array[RBI::Node]).void }
      def visit_all(nodes)
        nodes.dup.each { |node| visit(node) }
      end

      sig { override.params(node: T.nilable(RBI::Node)).void }
      def visit(node)
        return unless node

        case node
        when RBI::Scope
          visit_all(node.nodes)
          previous = previous_definition_for(node)
          delete_node(node, previous) if previous && node.empty?
        when RBI::Tree
          visit_all(node.nodes)
        when RBI::Indexable
          previous = previous_definition_for(node)
          delete_node(node, previous) if previous
        end
      end

      private

      sig { params(node: RBI::Indexable).returns(T.nilable(RBI::Node)) }
      def previous_definition_for(node)
        node.index_ids.each do |id|
          previous = @index[id].first
          return previous if previous
        end
        nil
      end

      sig { params(node: RBI::Node, previous: RBI::Node).void }
      def delete_node(node, previous)
        node.detach
        @operations << Operation.new(deleted_node: node, duplicate_of: previous)
      end

      class Operation < T::Struct
        extend T::Sig

        const :deleted_node, RBI::Node
        const :duplicate_of, RBI::Node

        sig { returns(String) }
        def to_s
          "Deleted #{duplicate_of} at #{deleted_node.loc} (duplicate from #{duplicate_of.loc})"
        end
      end
    end
  end
end
