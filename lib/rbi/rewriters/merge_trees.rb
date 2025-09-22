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
              if merge_nodes?(prev, node) || @keep == Keep::LEFT
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
            merge_comments(current_scope, node)
            visit_all(node.nodes)
          when Indexable
            prev = previous_definition(node)
            if prev
              if merge_nodes?(prev, node) || @keep == Keep::LEFT
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

        #: (NodeWithComments left, NodeWithComments right) -> void
        def merge_comments(left, right)
          right.comments.each do |comment|
            left.comments << comment unless left.comments.include?(comment)
          end
        end

        # Returns false if nodes are incompatible. This method merges any
        # type references in the node, but the caller is responsible for
        # merging children if the return value is true.
        #: (Node left, Node right) -> bool
        def merge_nodes?(left, right)
          return false unless left.class == right.class

          merge_comments(left, right) if left.is_a?(NodeWithComments) && right.is_a?(NodeWithComments)

          case left
          when Class
            right = right #: as Class
            left_superclass = lookup_type(name: left.superclass_name, referrer: left)
            right_superclass = lookup_type(name: right.superclass_name, referrer: right)
            left_superclass == right_superclass
          when Struct
            right = right #: as Struct
            left.members == right.members && left.keyword_init == right.keyword_init
          when Const
            right = right #: as Const
            left.name == right.name && left.value == right.value
          when Attr, Method
            right = right #: as Attr | Method
            return false if left.is_a?(Method) && right.is_a?(Method) && left.params != right.params
            return false if left.is_a?(Attr) && right.is_a?(Attr) && left.names != right.names

            left_sigs = left.sigs.map { fully_qualify_sig(_1, referrer: left) }
            right_sigs = right.sigs.map { fully_qualify_sig(_1, referrer: right) }
            if left_sigs.empty? || right_sigs.empty? || left_sigs == right_sigs
              right_sigs.each do |sig|
                left_sigs << sig unless left_sigs.include?(sig)
              end
              left.sigs = left_sigs
              true
            else
              false
            end
          when Mixin
            right = right #: as Mixin
            left_mixins = left.names.map { lookup_type(name: _1, referrer: left) }
            right_mixins = right.names.map { lookup_type(name: _1, referrer: right) }
            left_mixins == right_mixins
          when Helper
            # Do Helper names need to be resolved to types?
            right = right #: as Helper
            left.name == right.name
          when Send
            right = right #: as Send
            left.method == right.method && left.args == right.args
          when TStructField
            right = right #: as TStructField
            left.name == right.name && left.type == right.type && left.default == right.default
          else
            true
          end
        end

        # Returns a node from the merge tree that corresponds to the given type name
        # when referenced from the given referrer Node. The referrer can be
        # in a different tree, but its scope chain names will be used to find
        # the referent in this merge tree.
        #: (name: String?, referrer: Node) -> (Scope | Const)?
        def lookup_type(name:, referrer:)
          return unless name

          if name.start_with?("::")
            referent = @index[name].last #: Node?
            if referent.is_a?(Scope) || referent.is_a?(Const)
              return referent
            elsif referent
              raise "Unexpected type #{referent} for #{name} with referrer #{referrer}"
            else
              return
            end
          end

          referrer_scope = referrer.is_a?(Scope) ? referrer : referrer.parent_scope #: Scope?
          loop do
            scoped_name = "#{referrer_scope&.fully_qualified_name}::#{name}"
            referent = @index[scoped_name].last #: Node?
            if referent.is_a?(Scope) || referent.is_a?(Const)
              return referent
            elsif referent
              raise "Unexpected type #{referent} for #{name} with referrer #{referrer}"
            end
            break unless referrer_scope

            referrer_scope = referrer_scope.parent_scope
          end
        end

        #: ((Type | String) type, referrer: Node) -> Type
        def fully_qualify_type(type, referrer:)
          case type
          when String
            fully_qualify_type(Type.parse_string(type), referrer:)
          when Type::Simple
            # Heuristic perf optimization: assume some common Ruby global classes like
            # Symbol, String, Integer, Float, etc, are global to skip the namespace lookup.
            if ASSUME_GLOBAL_CLASS.include?(type.name)
              type
            else
              referent = lookup_type(
                name: type.name,
                referrer: referrer,
              )
              Type.simple(referent&.fully_qualified_name || type.name)
            end
          when Type::Nilable
            Type.nilable(fully_qualify_type(type.type, referrer:))
          when Type::Composite, Type::Tuple
            type.class.new(type.types.map { fully_qualify_type(_1, referrer:) })
          when Type::Generic
            Type.generic(type.name, *type.params.map { fully_qualify_type(_1, referrer:) })
          when Type::TypeAlias
            Type.type_alias(type.name, fully_qualify_type(type.aliased_type, referrer:))
          when Type::Shape
            Type.shape(type.types.transform_values { fully_qualify_type(_1, referrer:) })
          when Type::Proc
            copy = Type.proc
            params = type.proc_params.transform_values { fully_qualify_type(_1, referrer:) }
            copy.params(*params) # This should be **params but sorbet seems to get tripped up?
            copy.returns(fully_qualify_type(type.proc_returns, referrer:))
            copy.bind(fully_qualify_type(T.must(type.proc_bind), referrer:)) if type.proc_bind
          else
            type
          end
        end

        #: (Sig sig, referrer: Node) -> Sig
        def fully_qualify_sig(sig, referrer:)
          Sig.new(
            params: sig.params.map do |param|
              SigParam.new(
                param.name,
                fully_qualify_type(param.type, referrer:),
                loc: param.loc,
                comments: param.comments,
              )
            end,
            return_type: fully_qualify_type(sig.return_type, referrer:),
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
