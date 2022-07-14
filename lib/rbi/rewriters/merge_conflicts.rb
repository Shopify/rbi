# typed: strict
# frozen_string_literal: true

module RBI
  module Rewriters
    class MergeConflicts < Visitor
      extend T::Sig

      class Keep < ::T::Enum
        enums do
          LEFT = new
          RIGHT = new
        end
      end

      sig { params(keep: Keep).void }
      def initialize(keep:)
        @keep = keep
      end

      sig { override.params(node: T.nilable(RBI::Node)).void }
      def visit(node)
        return unless node

        case node
        when RBI::ConflictTree
          case @keep
          when Keep::LEFT
            node.replace(node.left)
          when Keep::RIGHT
            node.replace(node.right)
          end
          visit_all(node.nodes)
        when Tree
          visit_all(node.nodes)
        end
      end
    end
  end

  class MergeTree < Tree
    extend T::Sig

    sig { params(keep: Rewriters::MergeConflicts::Keep).void }
    def merge_conflicts!(keep:)
      rewriter = Rewriters::MergeConflicts.new(keep: keep)
      rewriter.visit(self)
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
    extend T::Sig

    sig { returns(Tree) }
    attr_reader :left, :right

    sig { params(left_name: String, right_name: String).void }
    def initialize(left_name: "left", right_name: "right")
      super()
      @left_name = left_name
      @right_name = right_name
      @left = T.let(Tree.new, Tree)
      @left.parent_tree = self
      @right = T.let(Tree.new, Tree)
      @right.parent_tree = self
    end

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      v.printl("<<<<<<< #{@left_name}")
      v.visit(left)
      v.printl("=======")
      v.visit(right)
      v.printl(">>>>>>> #{@right_name}")
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
    extend T::Sig

    sig { returns(Scope) }
    attr_reader :left, :right

    sig do
      params(
        left: Scope,
        right: Scope,
        left_name: String,
        right_name: String
      ).void
    end
    def initialize(left:, right:, left_name: "left", right_name: "right")
      super()
      @left = left
      @right = right
      @left_name = left_name
      @right_name = right_name
    end

    sig { override.params(v: Printer).void }
    def accept_printer(v)
      previous_node = v.previous_node
      v.printn if previous_node && (!previous_node.oneline? || !oneline?)

      v.printl("# #{loc}") if loc && v.print_locs
      v.visit_all(comments)

      v.printl("<<<<<<< #{@left_name}")
      left.print_header(v)
      v.printl("=======")
      right.print_header(v)
      v.printl(">>>>>>> #{@right_name}")
      left.print_body(v)
    end

    sig { override.returns(T::Boolean) }
    def oneline?
      left.oneline?
    end
  end
end
