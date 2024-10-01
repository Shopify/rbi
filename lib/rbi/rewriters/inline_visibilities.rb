# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class InlineVisibilities < Visitor
      #: -> void
      def initialize
        super

        @current_visibility = Public.new #: Visibility
      end

      # @override
      #: (Node? node) -> void
      def visit(node)
        return unless node

        case node
        when Public, Protected, Private
          @current_visibility = node
          node.detach
        when Tree
          @current_visibility = Public.new
          visit_all(node.nodes)
        when Method
          node.visibility = @current_visibility
        end
      end
    end
  end

  class Tree
    #: -> void
    def inline_visibilities!
      visitor = Rewriters::InlineVisibilities.new
      visitor.visit(self)
    end
  end
end