# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class Annotate < Visitor
      extend T::Sig

      sig { params(annotation: String).void }
      def initialize(annotation)
        super()
        @annotation = annotation
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        case node
        when Scope, Const, Attr, Method, TStructField, TypeMember
          annotate_node(node)
        end
        visit_all(node.nodes) if node.is_a?(Tree)
      end

      private

      sig { params(node: NodeWithComments).void }
      def annotate_node(node)
        return if node.annotations.one?(@annotation)
        node.comments << Comment.new("@#{@annotation}")
      end
    end
  end

  class Tree
    extend T::Sig

    sig { params(annotation: String).void }
    def annotate!(annotation)
      visitor = Rewriters::Annotate.new(annotation)
      visitor.visit(self)
    end
  end
end
