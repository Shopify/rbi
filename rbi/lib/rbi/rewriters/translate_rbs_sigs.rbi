# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Translate all RBS signature comments to Sorbet RBI signatures
    class TranslateRBSSigs < Visitor
      class Error < RBI::Error; end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: T.any(Method, Attr)).returns(Array) }
      def extract_rbs_comments(node); end

      sig { params(node: Method, comment: RBSComment).returns(Sig) }
      def translate_rbs_method_type(node, comment); end

      sig { params(node: Attr, comment: RBSComment).returns(Sig) }
      def translate_rbs_attr_type(node, comment); end
    end
  end

  class Tree
    sig { void }
    def translate_rbs_sigs!; end
  end
end
