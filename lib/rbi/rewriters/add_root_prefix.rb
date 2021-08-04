# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class AddRootPrefix < Visitor
      extend T::Sig

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node

        case node
        when Module, Class
          add_root_prefix(node)
          visit_all(node.nodes)
        when Const
          add_root_prefix(node)
        when Tree
          visit_all(node.nodes)
        end
      end

      # TODO: add to include, extend, micm
      # TODO: add to superclass

      sig { params(node: T.any(Module, Class, Const)).void }
      def add_root_prefix(node)
        return if node.name.start_with?("::")
        return if node.parent_scope
        node.name = "::#{node.name}"
      end
    end
  end

  class Tree
    extend T::Sig

    sig { void }
    def add_root_prefix!
      visitor = Rewriters::AddRootPrefix.new
      visitor.visit(self)
    end
  end
end
