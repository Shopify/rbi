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
          visit_all(node.nodes)
        when Tree
          visit_all(node.nodes)
        else
          return if node.parent_tree
        end
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
