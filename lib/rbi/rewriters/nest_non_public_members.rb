# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class NestNonPublicMembers < Visitor
      # @override
      #: (Node? node) -> void
      def visit(node)
        return unless node

        case node
        when Tree
          public_group = VisibilityGroup.new(Public.new)
          protected_group = VisibilityGroup.new(Protected.new)
          private_group = VisibilityGroup.new(Private.new)

          # Classify children in a single pass, avoiding O(n) Array#delete
          # calls from `detach` in a loop.
          remaining = []
          node.nodes.each do |child|
            visit(child)
            if child.is_a?(Attr) || child.is_a?(Method)
              child.parent_tree = nil
              case child.visibility
              when Protected
                protected_group << child
              when Private
                private_group << child
              else
                public_group << child
              end
            else
              remaining << child
            end
          end

          has_groups = !public_group.empty? || !protected_group.empty? || !private_group.empty?
          if has_groups
            node.nodes.replace(remaining)
            node << public_group unless public_group.empty?
            node << protected_group unless protected_group.empty?
            node << private_group unless private_group.empty?
          end
        end
      end
    end
  end

  class Tree
    #: -> void
    def nest_non_public_members!
      visitor = Rewriters::NestNonPublicMembers.new
      visitor.visit(self)
    end
  end

  class VisibilityGroup < Tree
    #: Visibility
    attr_reader :visibility

    #: (Visibility visibility) -> void
    def initialize(visibility)
      super()
      @visibility = visibility
    end
  end
end
