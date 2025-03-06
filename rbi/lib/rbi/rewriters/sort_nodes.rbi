# typed: strict
# frozen_string_literal: true

# The child nodes could contain private/protected markers. If so, they should not be moved in the file.
# Otherwise, some methods could see their privacy change. To avoid that problem, divide the array of child
# nodes into chunks based on whether any Visibility nodes appear, and sort the chunks independently. This
# applies the ordering rules from the node_rank method as much as possible, while preserving visibility.

# First we try to compare the nodes by their node rank (based on the node type)

# we can sort the nodes by their rank, let's stop here

# Then, if the nodes ranks are the same (res == 0), we try to compare the nodes by their name

# we can sort the nodes by their name, let's stop here

# Finally, if the two nodes have the same rank and the same name or at least one node is anonymous then,
# we keep the original order

# we never want to sort these nodes by their name

module RBI
  module Rewriters
    class SortNodes < Visitor
      # @override
      sig { params(node: T.nilable(Node)).void }
      def visit(node); end

      private

      sig { params(node: Node).returns(Integer) }
      def node_rank(node); end

      sig { params(kind: Group::Kind).returns(Integer) }
      def group_rank(kind); end

      sig { params(node: Node).returns(T.nilable(String)) }
      def node_name(node); end

      sig { params(node: Node).void }
      def sort_node_names!(node); end
    end
  end

  class Tree
    sig { void }
    def sort_nodes!; end
  end
end
