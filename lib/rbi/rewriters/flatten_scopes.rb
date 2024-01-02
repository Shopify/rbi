# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class FlattenScopes < Visitor
      extend T::Sig

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node

        case node
        when Tree
          visit_all(node.nodes)

          parent_tree = node.parent_tree
          return unless parent_tree

          node.nodes.dup.each do |child|
            next unless child.is_a?(Class) || child.is_a?(Module)

            parent_scope = child.parent_scope
            next unless parent_scope.is_a?(Class) || parent_scope.is_a?(Module)

            child.detach
            child.name = "#{parent_scope.name}::#{child.name}"
            parent_tree << child
          end
        end
      end
    end
  end

  class Tree
    extend T::Sig

    sig { void }
    def flatten_scopes!
      visitor = Rewriters::FlattenScopes.new
      visitor.visit(self)
    end
  end
end
