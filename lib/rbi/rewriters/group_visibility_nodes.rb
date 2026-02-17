# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Groups nodes after visibility modifiers into VisibilityGroup nodes
    #
    # This rewriter transforms a flat list of nodes where visibility modifiers
    # appear inline, into a nested structure where nodes following a visibility
    # modifier are grouped under a VisibilityGroup.
    #
    # Example:
    #   class Foo
    #     def public_method; end
    #
    #     private
    #
    #     def private_method1; end
    #     def private_method2; end
    #
    #     protected
    #
    #     def protected_method; end
    #   end
    #
    # Becomes:
    #   class Foo
    #     def public_method; end
    #
    #     VisibilityGroup(private)
    #       def private_method1; end
    #       def private_method2; end
    #
    #     VisibilityGroup(protected)
    #       def protected_method; end
    #   end
    class GroupVisibilityNodes < Visitor
      #: (Tree tree) -> void
      def self.group(tree)
        new.visit(tree)
      end

      # @override
      #: (Node? node) -> void
      def visit(node)
        return unless node.is_a?(Tree)

        visit_all(node.nodes)

        # Group visibility modifiers and their following nodes
        new_nodes = [] #: Array[Node]
        current_visibility = nil #: Visibility?
        current_group = nil #: ::RBI::VisibilityGroup?

        node.nodes.dup.each do |child|
          case child
          when Visibility
            # Start a new visibility group
            if current_group
              new_nodes << current_group
            end
            current_visibility = child
            current_group = ::RBI::VisibilityGroup.new(
              child,
              loc: child.loc,
              comments: child.comments,
            )
            child.detach
          else
            # Add node to current group or to the tree
            if current_group
              child.detach
              current_group << child
            else
              new_nodes << child
            end
          end
        end

        # Add the last group if any
        if current_group
          new_nodes << current_group
        end

        # Replace the tree's nodes
        node.nodes.clear
        new_nodes.each { |n| node << n }
      end
    end
  end
end
