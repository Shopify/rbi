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
      sig { void }
      def initialize; end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end
    end
  end

  class Tree
    sig { void }
    def flatten_visibilities!; end
  end
end
