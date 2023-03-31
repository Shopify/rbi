# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class Annotate < Visitor
      extend T::Sig

      sig { params(annotation: String, annotate_scopes: T::Boolean, annotate_properties: T::Boolean).void }
      def initialize(annotation, annotate_scopes: false, annotate_properties: false)
        super()
        @annotation = annotation
        @annotate_scopes = annotate_scopes
        @annotate_properties = annotate_properties
      end

      sig { override.params(node: T.nilable(Node)).void }
      def visit(node)
        case node
        when Scope
          annotate_node(node) if @annotate_scopes || root?(node)
        when Const, Attr, Method, TStructField, TypeMember
          annotate_node(node) if @annotate_properties
        end
        visit_all(node.nodes) if node.is_a?(Tree)
      end

      private

      sig { params(node: NodeWithComments).void }
      def annotate_node(node)
        return if node.annotations.one?(@annotation)

        node.comments << Comment.new("@#{@annotation}")
      end

      sig { params(node: Node).returns(T::Boolean) }
      def root?(node)
        parent = node.parent_tree
        parent.is_a?(Tree) && parent.parent_tree.nil?
      end
    end
  end

  class Tree
    extend T::Sig

    sig { params(annotation: String, annotate_scopes: T::Boolean, annotate_properties: T::Boolean).void }
    def annotate!(annotation, annotate_scopes: false, annotate_properties: false)
      visitor = Rewriters::Annotate.new(
        annotation,
        annotate_scopes: annotate_scopes,
        annotate_properties: annotate_properties,
      )
      visitor.visit(self)
    end
  end
end
