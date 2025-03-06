# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class AddSigTemplates < Visitor
      sig { params(with_todo_comment: T::Boolean).void }
      def initialize(with_todo_comment: true); end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(attr: Attr).void }
      def add_attr_sig(attr); end

      sig { params(method: Method).void }
      def add_method_sig(method); end

      sig { params(node: NodeWithComments).void }
      def add_todo_comment(node); end
    end
  end

  class Tree
    sig { params(with_todo_comment: T::Boolean).void }
    def add_sig_templates!(with_todo_comment: true); end
  end
end
