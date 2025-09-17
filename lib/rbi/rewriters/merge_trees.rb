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
      ASSUME_GLOBAL_CLASS = ["String", "Symbol", "Integer", "Float", "NilClass", "TrueClass", "FalseClass"].freeze

      class Keep
        NONE = new #: Keep
        LEFT = new #: Keep
        RIGHT = new #: Keep

        private_class_method(:new)
      end

      class << self
        #: (Tree left, Tree right, ?left_name: String, ?right_name: String, ?keep: Keep) -> MergeTree
        def merge_trees(left, right, left_name: "left", right_name: "right", keep: Keep::NONE)
          left.nest_singleton_methods!
          right.nest_singleton_methods!
          rewriter = Rewriters::Merge.new(left_name: left_name, right_name: right_name, keep: keep)
          rewriter.merge(left)
          rewriter.merge(right)
          tree = rewriter.tree
          ConflictTreeMerger.new.visit(tree)
          tree
        end

        # Returns a node from in_index that corresponds to the given type name
        # when referenced from the given referrer Node. The referrer can be
        # in a different tree, but its scope chain names will be used to find
        # the referent in in_index.
        #: (name: String?, referrer: Node, in_index: Index) -> Node?
        def lookup_type(name:, referrer:, in_index:)
          return unless name

          return in_index[name] if name.start_with?("::")

          referrer_scope = referrer.is_a?(Scope) ? referrer : referrer.parent_scope
          loop do
            scoped_name = "#{referrer_scope&.fully_qualified_name}::#{name}"
            referent = in_index[scoped_name].last
            break referent if referent
            break unless referrer_scope

            referrer_scope = referrer_scope.parent_scope
          end
        end

        #: ((Type | String) type, referrer: Node, in_index: Index) -> Type
        def fully_qualify_type(type, referrer:, in_index:)
          case type
          when String
            fully_qualify_type(Type.parse_string(type), referrer:, in_index:)
          when Type::Simple
            # Heuristic perf optimization: assume some common Ruby global classes like
            # Symbol, String, Integer, Float, etc, are global to skip the namespace lookup.
            if ASSUME_GLOBAL_CLASS.include?(type.name)
              type
            else
              referent = lookup_type(
                name: type.name,
                referrer: referrer,
                in_index:,
              )
              Type.simple(referent&.fully_qualified_name || type.name)
            end
          when Type::Nilable
            Type.nilable(fully_qualify_type(type.type, referrer:, in_index:))
          when Type::Composite, Type::Tuple
            type.class.new(type.types.map { fully_qualify_type(_1, referrer:, in_index:) })
          when Type::Generic
            Type.generic(type.name, *type.params.map { fully_qualify_type(_1, referrer:, in_index:) })
          when Type::TypeAlias
            Type.type_alias(type.name, fully_qualify_type(type.aliased_type, referrer:, in_index:))
          when Type::Shape
            Type.shape(type.types.transform_values { fully_qualify_type(_1, referrer:, in_index:) })
          when Type::Proc
            Type.proc
              .params(type.proc_params.transform_values { fully_qualify_type(_1, referrer:, in_index:) })
              .returns(fully_qualify_type(type.proc_returns, referrer:, in_index:))
              .bind(fully_qualify_type(type.proc_bind, referrer:, in_index:))
          else
            type
          end
        end

        #: (Sig sig, referrer: Node, in_index: Index) -> Sig
        def fully_qualify_sig(sig, referrer:, in_index:)
          Sig.new(
            params: sig.params.map do |param|
              SigParam.new(
                param.name,
                fully_qualify_type(param.type, referrer:, in_index:),
                loc: param.loc,
                comments: param.comments,
              )
            end,
            return_type: fully_qualify_type(sig.return_type, referrer:, in_index:),
            is_abstract: sig.is_abstract,
            is_override: sig.is_override,
            is_overridable: sig.is_overridable,
            is_final: sig.is_final,
            allow_incompatible_override: sig.allow_incompatible_override,
            without_runtime: sig.without_runtime,
            type_params: sig.type_params,
            checked: sig.checked,
            loc: sig.loc,
            comments: sig.comments,
          )
        end
      end

      #: MergeTree
      attr_reader :tree

      #: (?left_name: String, ?right_name: String, ?keep: Keep) -> void
      def initialize(left_name: "left", right_name: "right", keep: Keep::NONE)
        @left_name = left_name
        @right_name = right_name
        @keep = keep
        @tree = MergeTree.new #: MergeTree
        @scope_stack = [@tree] #: Array[Tree]
      end

      #: (Tree tree) -> void
      def merge(tree)
        v = TreeMerger.new(@tree, left_name: @left_name, right_name: @right_name, keep: @keep)
        v.visit(tree)
        @tree.conflicts.concat(v.conflicts)
      end

      # Used for logging / error displaying purpose
      class Conflict
        #: Node
        attr_reader :left, :right

        #: String
        attr_reader :left_name, :right_name

        #: (left: Node, right: Node, left_name: String, right_name: String) -> void
        def initialize(left:, right:, left_name:, right_name:)
          @left = left
          @right = right
          @left_name = left_name
          @right_name = right_name
        end

        #: -> String
        def to_s
          "Conflicting definitions for `#{left}`"
        end
      end

      class TreeMerger < Visitor
        #: Array[Conflict]
        attr_reader :conflicts

        #: (Tree output, ?left_name: String, ?right_name: String, ?keep: Keep) -> void
        def initialize(output, left_name: "left", right_name: "right", keep: Keep::NONE)
          super()
          @tree = output
          @index = output.index #: Index
          @scope_stack = [@tree] #: Array[Tree]
          @left_name = left_name
          @right_name = right_name
          @keep = keep
          @conflicts = [] #: Array[Conflict]
        end

        # @override
        #: (Node? node) -> void
        def visit(node)
          return unless node

          case node
          when Scope
            prev = previous_definition(node)

            if prev.is_a?(Scope)
              if node.compatible_with?(prev, in_index: @index)
                prev.merge_with(node, in_index: @index)
              elsif @keep == Keep::LEFT
                # do nothing it's already merged
              elsif @keep == Keep::RIGHT
                prev = replace_scope_header(prev, node)
              else
                make_conflict_scope(prev, node)
              end
              @scope_stack << prev
            else
              copy = node.dup_empty
              current_scope << copy
              @index.index(copy)
              @scope_stack << copy
            end
            visit_all(node.nodes)
            @scope_stack.pop
          when Tree
            current_scope.merge_with(node, in_index: @index)
            visit_all(node.nodes)
          when Indexable
            prev = previous_definition(node)
            if prev
              if node.compatible_with?(prev, in_index: @index)
                prev.merge_with(node, in_index: @index)
              elsif @keep == Keep::LEFT
                # do nothing it's already merged
              elsif @keep == Keep::RIGHT
                prev.replace(node)
              else
                make_conflict_tree(prev, node)
              end
            else
              copy = node.dup
              current_scope << copy
              @index.index(copy)
            end
          end
        end

        private

        #: -> Tree
        def current_scope
          @scope_stack.last #: as !nil
        end

        #: (Node node) -> Node?
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

        #: (Scope left, Scope right) -> void
        def make_conflict_scope(left, right)
          @conflicts << Conflict.new(left: left, right: right, left_name: @left_name, right_name: @right_name)
          scope_conflict = ScopeConflict.new(left: left, right: right, left_name: @left_name, right_name: @right_name)
          left.replace(scope_conflict)
        end

        #: (Node left, Node right) -> void
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

        #: (Scope left, Scope right) -> Scope
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
        # @override
        #: (Node? node) -> void
        def visit(node)
          visit_all(node.nodes) if node.is_a?(Tree)
        end

        # @override
        #: (Array[Node] nodes) -> void
        def visit_all(nodes)
          last_conflict_tree = nil #: ConflictTree?
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

        #: (Tree left, Tree right) -> void
        def merge_conflict_trees(left, right)
          right.nodes.dup.each do |node|
            left << node
          end
        end
      end
    end
  end

  class Node
    # Can `self` be merged into `_prev`?
    #: (Node _prev, in_index: Index) -> bool
    def compatible_with?(_prev, in_index:)
      true
    end

    # Merge `self` and `other` into a single definition
    #: (Node other, in_index: Index) -> void
    def merge_with(other, in_index:); end

    #: -> ConflictTree?
    def parent_conflict_tree
      parent = parent_tree #: Node?
      while parent
        return parent if parent.is_a?(ConflictTree)

        parent = parent.parent_tree
      end
      nil
    end
  end

  class NodeWithComments
    # @override
    #: (Node other) -> void
    def merge_with(other, **)
      return unless other.is_a?(NodeWithComments)

      other.comments.each do |comment|
        comments << comment unless comments.include?(comment)
      end
    end
  end

  class Tree
    #: (Tree other, ?left_name: String, ?right_name: String, ?keep: Rewriters::Merge::Keep) -> MergeTree
    def merge(other, left_name: "left", right_name: "right", keep: Rewriters::Merge::Keep::NONE)
      Rewriters::Merge.merge_trees(self, other, left_name: left_name, right_name: right_name, keep: keep)
    end
  end

  # A tree that _might_ contain conflicts
  class MergeTree < Tree
    #: Array[Rewriters::Merge::Conflict]
    attr_reader :conflicts

    #: (?loc: Loc?, ?comments: Array[Comment], ?conflicts: Array[Rewriters::Merge::Conflict]) ?{ (Tree node) -> void } -> void
    def initialize(loc: nil, comments: [], conflicts: [], &block)
      super(loc: loc, comments: comments)
      @conflicts = conflicts
      block&.call(self)
    end
  end

  class DuplicateNodeError < Error; end

  class Scope
    # Duplicate `self` scope without its body
    #: -> self
    def dup_empty
      case self
      when Module
        Module.new(name, loc: loc, comments: comments)
      when TEnum
        TEnum.new(name, loc: loc, comments: comments)
      when TEnumBlock
        TEnumBlock.new(loc: loc, comments: comments)
      when TStruct
        TStruct.new(name, loc: loc, comments: comments)
      when Class
        Class.new(name, superclass_name: superclass_name, loc: loc, comments: comments)
      when Struct
        Struct.new(name, members: members, keyword_init: keyword_init, loc: loc, comments: comments)
      when SingletonClass
        SingletonClass.new(loc: loc, comments: comments)
      else
        raise DuplicateNodeError, "Can't duplicate node #{self}"
      end
    end
  end

  class Class
    # @override
    #: (Node prev, in_index: Index) -> bool
    def compatible_with?(prev, in_index:)
      return false unless prev.is_a?(Class)

      self_superclass = Rewriters::Merge.lookup_type(
        name: superclass_name,
        referrer: self,
        in_index:,
      )
      prev_superclass = Rewriters::Merge.lookup_type(
        name: prev.superclass_name,
        referrer: prev,
        in_index:,
      )
      self_superclass == prev_superclass
    end
  end

  class Module
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Module)
    end
  end

  class Struct
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Struct) && members == other.members && keyword_init == other.keyword_init
    end
  end

  class Const
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Const) && name == other.name && value == other.value
    end
  end

  class Attr
    # @override
    #: (Node other, in_index: Index) -> bool
    def compatible_with?(prev, in_index:)
      return false unless prev.is_a?(Attr)
      return false unless names == prev.names

      lhs_sigs = sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: self, in_index:)
      end
      rhs_sigs = prev.sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: prev, in_index:)
      end

      lhs_sigs.empty? || rhs_sigs.empty? || lhs_sigs == rhs_sigs
    end

    # @override
    #: (Node other, in_index: Index) -> void
    def merge_with(other, in_index:)
      return unless other.is_a?(Attr)

      super

      merged_sigs = sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: self, in_index:)
      end
      rhs_sigs = other.sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: other, in_index:)
      end
      rhs_sigs.each do |sig|
        merged_sigs << sig unless merged_sigs.include?(sig)
      end
      self.sigs = merged_sigs
    end
  end

  class AttrReader
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(AttrReader) && super
    end
  end

  class AttrWriter
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(AttrWriter) && super
    end
  end

  class AttrAccessor
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(AttrAccessor) && super
    end
  end

  class Method
    # @override
    #: (Node prev, in_index: Index) -> bool
    def compatible_with?(prev, in_index:)
      return false unless prev.is_a?(Method)
      return false unless name == prev.name
      return false unless params == prev.params

      lhs_sigs = sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: self, in_index:)
      end
      rhs_sigs = prev.sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: prev, in_index:)
      end

      lhs_sigs.empty? || rhs_sigs.empty? || lhs_sigs == rhs_sigs
    end

    # @override
    #: (Node other, in_index: Index) -> void
    def merge_with(other, in_index:)
      return unless other.is_a?(Method)

      super

      merged_sigs = sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: self, in_index:)
      end
      rhs_sigs = other.sigs.map do |sig|
        Rewriters::Merge.fully_qualify_sig(sig, referrer: other, in_index:)
      end
      rhs_sigs.each do |sig|
        merged_sigs << sig unless merged_sigs.include?(sig)
      end
      self.sigs = merged_sigs
    end
  end

  class Mixin
    # @override
    #: (Node other, in_index: Index) -> bool
    def compatible_with?(other, in_index:)
      return false unless other.is_a?(Mixin)

      lhs_mixins = names.map do |name|
        Rewriters::Merge.lookup_type(
          name:,
          referrer: self,
          in_index:,
        )
      end
      rhs_mixins = other.names.map do |name|
        Rewriters::Merge.lookup_type(
          name:,
          referrer: other,
          in_index:,
        )
      end
      lhs_mixins == rhs_mixins
    end
  end

  class Include
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Include) && super
    end
  end

  class Extend
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Extend) && super
    end
  end

  class MixesInClassMethods
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(MixesInClassMethods) && super
    end
  end

  class Helper
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Helper) && name == other.name
    end
  end

  class Send
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(Send) && method == other.method && args == other.args
    end
  end

  class TStructField
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(TStructField) && name == other.name && type == other.type && default == other.default
    end
  end

  class TStructConst
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(TStructConst) && super
    end
  end

  class TStructProp
    # @override
    #: (Node other) -> bool
    def compatible_with?(other, **)
      other.is_a?(TStructProp) && super
    end
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
    #: Tree
    attr_reader :left, :right

    #: String
    attr_reader :left_name, :right_name

    #: (?left_name: String, ?right_name: String) -> void
    def initialize(left_name: "left", right_name: "right")
      super()
      @left_name = left_name
      @right_name = right_name
      @left = Tree.new #: Tree
      @left.parent_tree = self
      @right = Tree.new #: Tree
      @right.parent_tree = self
    end
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
    #: Scope
    attr_reader :left, :right

    #: String
    attr_reader :left_name, :right_name

    #: (left: Scope, right: Scope, ?left_name: String, ?right_name: String) -> void
    def initialize(left:, right:, left_name: "left", right_name: "right")
      super()
      @left = left
      @right = right
      @left_name = left_name
      @right_name = right_name
    end
  end
end
