# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class Deannotate < Visitor
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
          deannotate_node(node)
        end
        visit_all(node.nodes) if node.is_a?(Tree)
      end

      private

      sig { params(node: NodeWithComments).void }
      def deannotate_node(node)
        return unless node.annotations.one?(@annotation)

        node.comments.reject! do |comment|
          comment.text == "@#{@annotation}"
        end
      end
    end
  end

  class Tree
    extend T::Sig

    sig { params(annotation: String).void }
    def deannotate!(annotation)
      visitor = Rewriters::Deannotate.new(annotation)
      visitor.visit(self)
    end
  end
end
