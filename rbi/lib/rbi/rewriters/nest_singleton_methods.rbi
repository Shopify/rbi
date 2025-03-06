# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class NestSingletonMethods < Visitor
      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end
    end
  end

  class Tree
    sig { void }
    def nest_singleton_methods!; end
  end
end
