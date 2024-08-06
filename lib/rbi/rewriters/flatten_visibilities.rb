# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Flattens visibility nodes into method nodes
    #
    # Example:
    # ~~~rb
    # class A
    #   def m1; end
    #   private
    #   def m2; end
    #   def m3; end
    # end
    # ~~~
    #
    # will be transformed into:
    #
    # ~~~rb
    # class A
    #   def m1; end
    #   private def m2; end
    #   private def m3; end
    # end
    # ~~~
    class FlattenVisibilities < Visitor
      extend T::Sig

      sig { void }
      def initialize
        super

        @current_visibility = T.let([Public.new], T::Array[Visibility])
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        return unless node

        case node
        when Public, Protected, Private
          @current_visibility[-1] = node
          node.detach
        when Tree
          @current_visibility << Public.new
          visit_all(node.nodes.dup)
          @current_visibility.pop
        when Attr, Method
          node.visibility = T.must(@current_visibility.last)
        end
      end
    end
  end

  class Tree
    extend T::Sig

    sig { void }
    def flatten_visibilities!
      visitor = Rewriters::FlattenVisibilities.new
      visitor.visit(self)
    end
  end
end
