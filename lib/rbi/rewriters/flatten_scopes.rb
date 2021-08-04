# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class FlattenScopes < Visitor
      extend T::Sig

      sig { returns(Tree) }
      attr_reader :root

      sig { void }
      def initialize
        super
        @root = T.let(Tree.new, Tree)
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node

        case node
        when Module, Class
          fully_qualified_name = node.fully_qualified_name
          node.detach
          root << node
          node.name = fully_qualified_name
        else
          move_toplevel_node(node)
        end

        if node.is_a?(Tree)
          visit_all(node.nodes.dup)
          clear_empty_tree(node)
        end
      end

      sig { params(node: Node).void }
      def move_toplevel_node(node)
        return if node.parent_scope
        return if node.instance_of?(Tree)
        puts node.to_s
        node.detach
        @root << node
      end

      sig { params(tree: Tree).void }
      def clear_empty_tree(tree)
        return unless tree.instance_of?(Tree) ||
          tree.instance_of?(Group) ||
          tree.instance_of?(VisibilityGroup)
        return unless tree.empty?
        tree.detach
      end
    end
  end

  class Tree
    extend T::Sig

    sig { returns(Tree) }
    def flatten_scopes
      visitor = Rewriters::FlattenScopes.new
      visitor.visit(self)
      visitor.root
    end
  end
end
