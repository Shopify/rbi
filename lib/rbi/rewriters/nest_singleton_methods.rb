# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class NestSingletonMethods < Visitor
      # @override
      #: (Node? node) -> void
      def visit(node)
        return unless node

        case node
        when Tree
          singleton_class = SingletonClass.new

          # Collect singleton methods and remaining nodes in a single pass,
          # avoiding O(n) Array#delete calls from `detach` in a loop.
          remaining = []
          node.nodes.each do |child|
            visit(child)
            if child.is_a?(Method) && child.is_singleton
              child.parent_tree = nil
              child.is_singleton = false
              singleton_class << child
            else
              remaining << child
            end
          end

          unless singleton_class.empty?
            node.nodes.replace(remaining)
            node << singleton_class
          end
        end
      end
    end
  end

  class Tree
    #: -> void
    def nest_singleton_methods!
      visitor = Rewriters::NestSingletonMethods.new
      visitor.visit(self)
    end
  end
end
