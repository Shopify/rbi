# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class Deannotate < Visitor
      sig { params(annotation: String).void }
      def initialize(annotation); end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: NodeWithComments).void }
      def deannotate_node(node); end
    end
  end

  class Tree
    sig { params(annotation: String).void }
    def deannotate!(annotation); end
  end
end
