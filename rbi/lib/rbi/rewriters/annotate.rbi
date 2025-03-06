# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class Annotate < Visitor
      sig { params(annotation: String, annotate_scopes: T::Boolean, annotate_properties: T::Boolean).void }
      def initialize(annotation, annotate_scopes: false, annotate_properties: false); end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: NodeWithComments).void }
      def annotate_node(node); end

      sig { params(node: Node).returns(T::Boolean) }
      def root?(node); end
    end
  end

  class Tree
    sig { params(annotation: String, annotate_scopes: T::Boolean, annotate_properties: T::Boolean).void }
    def annotate!(annotation, annotate_scopes: false, annotate_properties: false); end
  end
end
