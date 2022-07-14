# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    # Merge two RBI trees together
    #
    # Be this `Tree`:
    # ~~~rb
    # class Foo
    #   attr_accessor :a
    #   def m; end
    #   C = 10
    # end
    # ~~~
    #
    # Merged with this one:
    # ~~~rb
    # class Foo
    #   attr_reader :a
    #   def m(x); end
    #   C = 10
    # end
    # ~~~
    #
    # Compatible definitions are merged together while incompatible definitions are moved into a `ConflictTree`:
    # ~~~rb
    # class Foo
    #   <<<<<<< left
    #   attr_accessor :a
    #   def m; end
    #   =======
    #   attr_reader :a
    #   def m(x); end
    #   >>>>>>> right
    #   C = 10
    # end
    # ~~~
    class Merge
      extend T::Sig

      sig { params(left: Tree, right: Tree, left_name: String, right_name: String).returns(MergeTree) }
      def self.merge_trees(left, right, left_name: "left", right_name: "right")
        left.nest_singleton_methods!
        right.nest_singleton_methods!
        rewriter = Rewriters::Merge.new(left_name: left_name, right_name: right_name)
        rewriter.merge(left)
        rewriter.merge(right)
        tree = rewriter.tree
        ConflictTreeMerger.new.visit(tree)
        tree
      end

      sig { returns(MergeTree) }
      attr_reader :tree

      sig { params(left_name: String, right_name: String).void }
      def initialize(left_name: "left", right_name: "right")
        @left_name = left_name
        @right_name = right_name
        @tree = T.let(MergeTree.new, MergeTree)
        @scope_stack = T.let([@tree], T::Array[Tree])
      end

      sig { params(tree: Tree).void }
      def merge(tree)
        v = TreeMerger.new(@tree, left_name: @left_name, right_name: @right_name)
        v.visit(tree)
        @tree.conflicts.concat(v.conflicts)
      end

      # Used for logging / error displaying purpose
      class Conflict < T::Struct
        extend T::Sig

        const :left, Node
        const :right, Node
        const :left_name, String
        const :right_name, String

        sig { returns(String) }
        def to_s
          "Conflicting definitions for `#{left}`"
        end
      end

      class TreeMerger < Visitor
        extend T::Sig

        sig { returns(T::Array[Conflict]) }
        attr_reader :conflicts

        sig { params(output: Tree, left_name: String, right_name: String).void }
        def initialize(output, left_name: "left", right_name: "right")
          super()
          @tree = output
          @index = T.let(output.index, Index)
          @scope_stack = T.let([@tree], T::Array[Tree])
          @left_name = left_name
          @right_name = right_name
          @conflicts = T.let([], T::Array[Conflict])
        end

        sig { override.params(node: T.nilable(Node)).void }
        def visit(node)
          return unless node

          case node
          when Scope
            prev = previous_definition(node)

            if prev.is_a?(Scope)
              if node.compatible_with?(prev)
                prev.merge_with(node)
              else
                make_conflict_scope(prev, node)
              end
              @scope_stack << prev
            else
              copy = node.dup_empty
              current_scope << copy
              @scope_stack << copy
            end
            visit_all(node.nodes)
            @scope_stack.pop
          when Tree
            current_scope.merge_with(node)
            visit_all(node.nodes)
          when Indexable
            prev = previous_definition(node)
            if prev
              if node.compatible_with?(prev)
                prev.merge_with(node)
              else
                make_conflict_tree(prev, node)
              end
            else
              current_scope << node.dup
            end
          end
        end

        private

        sig { returns(Tree) }
        def current_scope
          T.must(@scope_stack.last)
        end

        sig { params(node: Node).returns(T.nilable(Node)) }
        def previous_definition(node)
          case node
          when Indexable
            node.index_ids.each do |id|
              others = @index[id]
              return others.last unless others.empty?
            end
          end
          nil
        end

        sig { params(left: Scope, right: Scope).void }
        def make_conflict_scope(left, right)
          @conflicts << Conflict.new(left: left, right: right, left_name: @left_name, right_name: @right_name)
          scope_conflict = ScopeConflict.new(left: left, right: right, left_name: @left_name, right_name: @right_name)
          left.replace(scope_conflict)
        end

        sig { params(left: Node, right: Node).void }
        def make_conflict_tree(left, right)
          @conflicts << Conflict.new(left: left, right: right, left_name: @left_name, right_name: @right_name)
          tree = left.parent_conflict_tree
          unless tree
            tree = ConflictTree.new(left_name: @left_name, right_name: @right_name)
            left.replace(tree)
            tree.left << left
          end
          tree.right << right
        end

        sig { params(left: Scope, right: Scope).returns(Scope) }
        def replace_scope_header(left, right)
          right_copy = right.dup_empty
          left.replace(right_copy)
          left.nodes.each do |node|
            right_copy << node
          end
          @index.index(right_copy)
          right_copy
        end
      end

      # Merge adjacent conflict trees
      #
      # Transform this:
      # ~~~rb
      # class Foo
      #   <<<<<<< left
      #   def m1; end
      #   =======
      #   def m1(a); end
      #   >>>>>>> right
      #   <<<<<<< left
      #   def m2(a); end
      #   =======
      #   def m2; end
      #   >>>>>>> right
      # end
      # ~~~
      #
      # Into this:
      # ~~~rb
      # class Foo
      #   <<<<<<< left
      #   def m1; end
      #   def m2(a); end
      #   =======
      #   def m1(a); end
      #   def m2; end
      #   >>>>>>> right
      # end
      # ~~~
      class ConflictTreeMerger < Visitor
        sig { override.params(node: T.nilable(Node)).void }
        def visit(node)
          visit_all(node.nodes) if node.is_a?(Tree)
        end

        sig { override.params(nodes: T::Array[Node]).void }
        def visit_all(nodes)
          last_conflict_tree = T.let(nil, T.nilable(ConflictTree))
          nodes.dup.each do |node|
            if node.is_a?(ConflictTree)
              if last_conflict_tree
                merge_conflict_trees(last_conflict_tree.left, node.left)
                merge_conflict_trees(last_conflict_tree.right, node.right)
                node.detach
                next
              else
                last_conflict_tree = node
              end
            end

            visit(node)
          end
        end

        private

        sig { params(left: Tree, right: Tree).void }
        def merge_conflict_trees(left, right)
          right.nodes.dup.each do |node|
            left << node
          end
        end
      end
    end
  end

  class Node
    extend T::Sig

    # Can `self` and `_other` be merged into a single definition?
    sig { params(_other: Node).returns(T::Boolean) }
    def compatible_with?(_other)
      true
    end

    # Merge `self` and `other` into a single definition
    sig { params(other: Node).void }
    def merge_with(other); end

    sig { returns(T.nilable(ConflictTree)) }
    def parent_conflict_tree
      parent = T.let(parent_tree, T.nilable(Node))
      while parent
        return parent if parent.is_a?(ConflictTree)
        parent = parent.parent_tree
      end
      nil
    end
  end

  class NodeWithComments
    extend T::Sig

    sig { override.params(other: Node).void }
    def merge_with(other)
      return unless other.is_a?(NodeWithComments)
      other.comments.each do |comment|
        comments << comment unless comments.include?(comment)
      end
    end
  end

  class Tree
    extend T::Sig

    sig { params(other: Tree, left_name: String, right_name: String).returns(MergeTree) }
    def merge(other, left_name: "left", right_name: "right")
      Rewriters::Merge.merge_trees(self, other, left_name: left_name, right_name: right_name)
    end
  end

  # A tree that _might_ contain conflicts
  class MergeTree < Tree
    extend T::Sig

    sig { returns(T::Array[Rewriters::Merge::Conflict]) }
    attr_reader :conflicts

    sig do
      params(
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        conflicts: T::Array[Rewriters::Merge::Conflict],
        block: T.nilable(T.proc.params(node: Tree).void)
      ).void
    end
    def initialize(loc: nil, comments: [], conflicts: [], &block)
      super(loc: loc, comments: comments)
      @conflicts = conflicts
      block&.call(self)
    end
  end

  class Scope
    extend T::Sig

    # Duplicate `self` scope without its body
    sig { returns(T.self_type) }
    def dup_empty
      case self
      when Module
        Module.new(name, loc: loc, comments: comments)
      when Class
        Class.new(name, superclass_name: superclass_name, loc: loc, comments: comments)
      when Struct
        Struct.new(name, members: members, keyword_init: keyword_init, loc: loc, comments: comments)
      when SingletonClass
        SingletonClass.new(loc: loc, comments: comments)
      else
        raise "Can't duplicate node #{self}"
      end
    end
  end

  class Class
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Class) && superclass_name == other.superclass_name
    end
  end

  class Module
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Module)
    end
  end

  class Struct
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Struct) && members == other.members && keyword_init == other.keyword_init
    end
  end

  class Const
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Const) && name == other.name && value == other.value
    end
  end

  class Attr
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      return false unless other.is_a?(Attr)
      return false unless names == other.names
      sigs.empty? || other.sigs.empty? || sigs == other.sigs
    end

    sig { override.params(other: Node).void }
    def merge_with(other)
      return unless other.is_a?(Attr)
      super
      other.sigs.each do |sig|
        sigs << sig unless sigs.include?(sig)
      end
    end
  end

  class AttrReader
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(AttrReader) && super
    end
  end

  class AttrWriter
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(AttrWriter) && super
    end
  end

  class AttrAccessor
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(AttrAccessor) && super
    end
  end

  class Method
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      return false unless other.is_a?(Method)
      return false unless name == other.name
      return false unless params == other.params
      sigs.empty? || other.sigs.empty? || sigs == other.sigs
    end

    sig { override.params(other: Node).void }
    def merge_with(other)
      return unless other.is_a?(Method)
      super
      other.sigs.each do |sig|
        sigs << sig unless sigs.include?(sig)
      end
    end
  end

  class Mixin
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Mixin) && names == other.names
    end
  end

  class Include
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Include) && super
    end
  end

  class Extend
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Extend) && super
    end
  end

  class MixesInClassMethods
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(MixesInClassMethods) && super
    end
  end

  class Helper
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Helper) && name == other.name
    end
  end

  class Send
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(Send) && method == other.method && args == other.args
    end
  end

  class TStructField
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(TStructField) && name == other.name && type == other.type && default == other.default
    end
  end

  class TStructConst
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(TStructConst) && super
    end
  end

  class TEnumBlock
    extend T::Sig

    sig { override.params(other: Node).void }
    def merge_with(other)
      return unless other.is_a?(TEnumBlock)
      super
      other.names.each do |name|
        names << name unless names.include?(name)
      end
    end
  end

  class TStructProp
    extend T::Sig

    sig { override.params(other: Node).returns(T::Boolean) }
    def compatible_with?(other)
      other.is_a?(TStructProp) && super
    end
  end
end
