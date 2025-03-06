# typed: strict
# frozen_string_literal: true

# do nothing it's already merged

# do nothing it's already merged

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
      class Keep < T::Enum
        enums do
          NONE = new
          LEFT = new
          RIGHT = new
        end
      end

      class << self
        sig { params(left: Tree, right: Tree, left_name: String, right_name: String, keep: Keep).returns(MergeTree) }
        def merge_trees(left, right, left_name: "left", right_name: "right", keep: Keep::NONE); end
      end

      sig { returns(MergeTree) }
      attr_reader :tree

      sig { params(left_name: String, right_name: String, keep: Keep).void }
      def initialize(left_name: "left", right_name: "right", keep: Keep::NONE); end

      sig { params(tree: Tree).void }
      def merge(tree); end

      # Used for logging / error displaying purpose
      class Conflict < T::Struct
        const :left, Node
        const :right, Node
        const :left_name, String
        const :right_name, String

        sig { returns(String) }
        def to_s; end
      end

      class TreeMerger < Visitor
        sig { returns(T::Array[Conflict]) }
        attr_reader :conflicts

        sig { params(output: Tree, left_name: String, right_name: String, keep: Keep).void }
        def initialize(output, left_name: "left", right_name: "right", keep: Keep::NONE); end

        # @override
        sig { params(node: T.nilable(Node)).void }
        def visit(node); end

        private

        sig { returns(Tree) }
        def current_scope; end

        sig { params(node: Node).returns(T.nilable(Node)) }
        def previous_definition(node); end

        sig { params(left: Scope, right: Scope).void }
        def make_conflict_scope(left, right); end

        sig { params(left: Node, right: Node).void }
        def make_conflict_tree(left, right); end

        sig { params(left: Scope, right: Scope).returns(Scope) }
        def replace_scope_header(left, right); end
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
        # @override
        sig { params(node: T.nilable(Node)).void }
        def visit(node); end

        # @override
        sig { params(nodes: T::Array[Node]).void }
        def visit_all(nodes); end

        private

        sig { params(left: Tree, right: Tree).void }
        def merge_conflict_trees(left, right); end
      end
    end
  end

  class Node
    # Can `self` and `_other` be merged into a single definition?
    sig { params(_other: Node).returns(T::Boolean) }
    def compatible_with?(_other); end

    # Merge `self` and `other` into a single definition
    sig { params(other: Node).void }
    def merge_with(other); end

    sig { returns(T.nilable(ConflictTree)) }
    def parent_conflict_tree; end
  end

  class NodeWithComments
    # @override
    sig { params(other: Node).void }
    def merge_with(other); end
  end

  class Tree
    sig { params(other: Tree, left_name: String, right_name: String, keep: Rewriters::Merge::Keep).returns(MergeTree) }
    def merge(other, left_name: "left", right_name: "right", keep: Rewriters::Merge::Keep::NONE); end
  end

  # A tree that _might_ contain conflicts
  class MergeTree < Tree
    sig { returns(T::Array[Rewriters::Merge::Conflict]) }
    attr_reader :conflicts

    sig { params(loc: T.nilable(Loc), comments: T::Array[Comment], conflicts: T::Array[Rewriters::Merge::Conflict], block: T.nilable(T.proc.params(node: Tree).void)).void }
    def initialize(loc: nil, comments: [], conflicts: [], &block); end
  end

  class DuplicateNodeError < Error; end

  class Scope
    # Duplicate `self` scope without its body
    sig { returns(T.self_type) }
    def dup_empty; end
  end

  class Class
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Module
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Struct
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Const
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Attr
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end

    # @override
    sig { params(other: Node).void }
    def merge_with(other); end
  end

  class AttrReader
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class AttrWriter
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class AttrAccessor
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Method
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end

    # @override
    sig { params(other: Node).void }
    def merge_with(other); end
  end

  class Mixin
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Include
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Extend
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class MixesInClassMethods
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Helper
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class Send
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class TStructField
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class TStructConst
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  class TStructProp
    # @override
    sig { params(other: Node).returns(T::Boolean) }
    def compatible_with?(other); end
  end

  # A tree showing incompatibles nodes
  #
  # Is rendered as a merge conflict between `left` and` right`:
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
  class ConflictTree < Tree
    sig { returns(Tree) }
    attr_reader :left, :right

    sig { returns(String) }
    attr_reader :left_name, :right_name

    sig { params(left_name: String, right_name: String).void }
    def initialize(left_name: "left", right_name: "right"); end
  end

  # A conflict between two scope headers
  #
  # Is rendered as a merge conflict between `left` and` right` for scope definitions:
  # ~~~rb
  # <<<<<<< left
  # class Foo
  # =======
  # module Foo
  # >>>>>>> right
  #   def m1; end
  # end
  # ~~~
  class ScopeConflict < Tree
    sig { returns(Scope) }
    attr_reader :left, :right

    sig { returns(String) }
    attr_reader :left_name, :right_name

    sig { params(left: Scope, right: Scope, left_name: String, right_name: String).void }
    def initialize(left:, right:, left_name: "left", right_name: "right"); end
  end
end
