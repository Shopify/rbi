# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # This rewriter moves top-level members into a top-level Object class
    #
    # Example:
    # ~~~rb
    # def foo; end
    # attr_reader :bar
    # ~~~
    #
    # will be rewritten to:
    #
    # ~~~rb
    # class Object
    #  def foo; end
    #  attr_reader :bar
    # end
    # ~~~
    class NestTopLevelMembers < Visitor
      sig { void }
      def initialize; end

      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end
    end
  end

  class Tree
    sig { void }
    def nest_top_level_members!; end
  end
end
