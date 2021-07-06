# typed: strict
# frozen_string_literal: true

module RBI
  class TreeCleaner < Tapioca::RBI::Visitor
    extend T::Sig

    sig do
      params(
        tree: Tapioca::RBI::Tree,
        index: Tapioca::RBI::Index
      ).returns([Tapioca::RBI::Tree, T::Array[Operation]])
    end
    def self.clean(tree, index)
      v = TreeCleaner.new(index)
      v.visit(tree)
      [tree, v.operations]
    end

    sig { returns(T::Array[Operation]) }
    attr_reader :operations

    sig { params(index: Tapioca::RBI::Index).void }
    def initialize(index)
      super()
      @index = index
      @operations = T.let([], T::Array[Operation])
    end

    sig { params(nodes: T::Array[Tapioca::RBI::Node]).void }
    def visit_all(nodes)
      nodes.dup.each { |node| visit(node) }
    end

    sig { override.params(node: T.nilable(Tapioca::RBI::Node)).void }
    def visit(node)
      return unless node

      case node
      when Tapioca::RBI::Scope
        visit_all(node.nodes)
        previous = previous_definition_for?(node)
        delete_node(node, previous) if previous && node.empty?
      when Tapioca::RBI::Tree
        visit_all(node.nodes)
      when Tapioca::RBI::Indexable
        previous = previous_definition_for?(node)
        delete_node(node, previous) if previous
      end
    end

    private

    sig { params(node: Tapioca::RBI::Indexable).returns(T.nilable(Tapioca::RBI::Node)) }
    def previous_definition_for?(node)
      node.index_ids.each do |id|
        previous = @index[id].first
        return previous if previous
      end
      nil
    end

    sig { params(node: Tapioca::RBI::Node, previous: Tapioca::RBI::Node).void }
    def delete_node(node, previous)
      node.detach
      @operations << Operation.new(deleted_node: node, duplicate_of: previous)
    end

    class Operation < T::Struct
      extend T::Sig

      const :deleted_node, Tapioca::RBI::Node
      const :duplicate_of, Tapioca::RBI::Node

      sig { returns(String) }
      def to_s
        "Deleted #{deleted_node} duplicate from #{duplicate_of.loc}"
      end
    end
  end
end
