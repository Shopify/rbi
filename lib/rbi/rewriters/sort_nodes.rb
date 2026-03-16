# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class SortNodes < Visitor
      # @override
      #: (Node? node) -> void
      def visit(node)
        sort_node_names!(node) if node

        return unless node.is_a?(Tree)

        visit_all(node.nodes)

        nodes = node.nodes
        return if nodes.size <= 1

        # Fast path: if no Visibility nodes are present (common after group_nodes!/nest_non_public_members!),
        # skip the chunk and sort directly.
        has_visibility = nodes.any? { |n| n.is_a?(Visibility) }

        if has_visibility
          # The child nodes contain private/protected markers. Divide into chunks
          # and sort each chunk independently to preserve visibility semantics.
          sorted_nodes = nodes.chunk { |n| n.is_a?(Visibility) }.flat_map do |_, chunk_nodes|
            chunk_nodes.sort_by!.with_index do |n, i|
              [node_rank(n), node_name(n) || "", i]
            end
          end
          nodes.replace(sorted_nodes)
        else
          # No visibility nodes — sort in place with Schwartzian transform.
          nodes.sort_by!.with_index do |n, i|
            [node_rank(n), node_name(n) || "", i]
          end
        end
      end

      private

      #: (Node node) -> Integer
      def node_rank(node)
        case node
        when Group                then group_rank(node.kind)
        when Include, Extend      then 10
        when RequiresAncestor     then 15
        when Helper               then 20
        when TypeMember           then 30
        when MixesInClassMethods  then 40
        when Send                 then 50
        when TStructField         then 60
        when TEnumBlock           then 70
        when Attr                 then 75
        when Method
          if node.name == "initialize"
            81
          elsif !node.is_singleton
            82
          else
            83
          end
        when SingletonClass       then 90
        when Scope, Const         then 100
        else
          110
        end
      end

      #: (Group::Kind kind) -> Integer
      def group_rank(kind)
        case kind
        when Group::Kind::Mixins              then 0
        when Group::Kind::RequiredAncestors   then 1
        when Group::Kind::Helpers             then 2
        when Group::Kind::TypeMembers         then 3
        when Group::Kind::MixesInClassMethods then 4
        when Group::Kind::Sends               then 5
        when Group::Kind::TStructFields       then 6
        when Group::Kind::TEnums              then 7
        when Group::Kind::Attrs               then 8
        when Group::Kind::Inits               then 9
        when Group::Kind::Methods             then 10
        when Group::Kind::SingletonClasses    then 11
        when Group::Kind::Consts              then 12
        else
          raise Error, "Unknown group kind: #{kind}"
        end
      end

      #: (Node node) -> String?
      def node_name(node)
        case node
        when Module, Class, Struct, Const, Method, Helper, RequiresAncestor
          node.name
        when Attr
          node.names.first.to_s
        when TStructField, Mixin
          nil # we never want to sort these nodes by their name
        end
      end

      #: (Node node) -> void
      def sort_node_names!(node)
        case node
        when Attr
          node.names.sort!
        end
      end
    end
  end

  class Tree
    #: -> void
    def sort_nodes!
      visitor = Rewriters::SortNodes.new
      visitor.visit(self)
    end
  end
end
