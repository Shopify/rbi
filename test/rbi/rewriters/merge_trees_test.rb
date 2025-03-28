# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class MergeTest < Minitest::Test
    include TestHelper

    def test_merge_empty_trees
      tree1 = Tree.new
      tree2 = Tree.new
      res = tree1.merge(tree2)
      assert_equal("", res.string)
    end

    def test_merge_empty_tree_into_tree
      tree1 = parse_rbi(<<~RBI)
        class Foo; end
      RBI

      tree2 = Tree.new

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class Foo; end
      RBI
    end

    def test_merge_tree_into_empty_tree
      tree1 = Tree.new

      tree2 = parse_rbi(<<~RBI)
        class Foo; end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class Foo; end
      RBI
    end

    def test_merge_scopes_together
      tree1 = parse_rbi(<<~RBI)
        class A; end
        class B; end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class C; end
        class D; end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A; end
        class B; end
        class C; end
        class D; end
      RBI
    end

    def test_merge_nested_scopes_together
      tree1 = parse_rbi(<<~RBI)
        class A
          class B; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class C
          class D; end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          class B; end
        end

        class C
          class D; end
        end
      RBI
    end

    def test_merge_same_scopes_together
      tree1 = parse_rbi(<<~RBI)
        class A
          class B; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          class B; end
          class C; end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          class B; end
          class C; end
        end
      RBI
    end

    def test_merge_constants_together
      tree1 = parse_rbi(<<~RBI)
        class A
          A = 42
        end
        B = 42
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          A = 42
          B = 42
        end
        B = 42
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          A = T.let(T.unsafe(nil), T.untyped)
          B = T.let(T.unsafe(nil), T.untyped)
        end

        B = T.let(T.unsafe(nil), T.untyped)
      RBI
    end

    def test_merge_attributes_together
      tree1 = parse_rbi(<<~RBI)
        class A
          attr_reader :a
          attr_writer :a
          attr_accessor :b
          attr_reader :c, :d
          attr_writer :e
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          attr_reader :a
          attr_writer :a
          attr_accessor :b
          attr_reader :c, :d
          attr_writer :f
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          attr_reader :a
          attr_writer :a
          attr_accessor :b
          attr_reader :c, :d
          attr_writer :e
          attr_writer :f
        end
      RBI
    end

    def test_merge_methods_together
      tree1 = parse_rbi(<<~RBI)
        class A
          def a; end
          def b; end
          def c(a, b:, &d); end
          def d(a); end
          def x(a = T.unsafe(nil), b: T.unsafe(nil)); end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          def a; end
          def b; end
          def c(a, b:, &d); end
          def e(a); end
          def x(a = false, b: "foo"); end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          def a; end
          def b; end
          def c(a, b:, &d); end
          def d(a); end
          def x(a = T.unsafe(nil), b: T.unsafe(nil)); end
          def e(a); end
        end
      RBI
    end

    def test_merge_mixins_together
      tree1 = parse_rbi(<<~RBI)
        class A
          include A
          extend B
          mixes_in_class_methods C
          include D, E, F
          include G
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          include A
          extend B
          mixes_in_class_methods C
          include D, E, F
          include H
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          include A
          extend B
          mixes_in_class_methods C
          include D, E, F
          include G
          include H
        end
      RBI
    end

    def test_merge_helpers_together
      tree1 = parse_rbi(<<~RBI)
        class A
          abstract!
          interface!
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          interface!
          sealed!
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          abstract!
          interface!
          sealed!
        end
      RBI
    end

    def test_merge_sends_together
      tree1 = parse_rbi(<<~RBI)
        class A
          foo :bar, :baz
          bar
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          foo :bar, :baz
          baz
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          foo :bar, :baz
          bar
          baz
        end
      RBI
    end

    def test_merge_type_members_together
      tree1 = parse_rbi(<<~RBI)
        class A
          Foo = type_member {{ fixed: Integer }}
          Bar = type_template {{ upper: String }}
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          Foo = type_member {
            { fixed: Integer }
          }
          Bar = type_template {
            { upper: String }
          }
          Baz = type_template
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          Foo = type_member {{ fixed: Integer }}
          Bar = type_template {{ upper: String }}
          Baz = type_template
        end
      RBI

      res = tree2.merge(tree1)
      assert_equal(<<~RBI, res.string)
        class A
          Foo = type_member {
            { fixed: Integer }
          }
          Bar = type_template {
            { upper: String }
          }
          Baz = type_template
        end
      RBI
    end

    def test_merge_structs_together
      tree1 = parse_rbi(<<~RBI)
        class A < T::Struct
          prop :a, Integer
          const :b, Integer
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A < T::Struct
          const :b, Integer
          prop :c, Integer
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A < T::Struct
          prop :a, Integer
          const :b, Integer
          prop :c, Integer
        end
      RBI
    end

    def test_merge_enums_together
      tree1 = parse_rbi(<<~RBI)
        class A < T::Enum
          enums do
            A = new
            B = new
          end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A < T::Enum
          enums do
            B = new
            C = new
          end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A < T::Enum
          enums do
            A = new
            B = new
            C = new
          end
        end
      RBI
    end

    def test_merge_signatures
      tree1 = parse_rbi(<<~RBI)
        class A
          def m1; end

          sig { void }
          def m2; end

          sig { returns(Integer) }
          def m3; end

          attr_reader :a1

          sig { void }
          attr_writer :a2

          sig { returns(Integer) }
          attr_accessor :a3
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          sig { returns(Integer) }
          def m1; end

          def m2; end

          sig { returns(Integer) }
          def m3; end

          sig { returns(Integer) }
          attr_reader :a1

          attr_writer :a2

          sig { returns(Integer) }
          attr_accessor :a3
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          sig { returns(Integer) }
          def m1; end

          sig { void }
          def m2; end

          sig { returns(Integer) }
          def m3; end

          sig { returns(Integer) }
          attr_reader :a1

          sig { void }
          attr_writer :a2

          sig { returns(Integer) }
          attr_accessor :a3
        end
      RBI
    end

    def test_merge_comments
      tree1 = parse_rbi(<<~RBI)
        # Comment A1
        class A
          # Comment a1
          attr_reader :a
          # Comment m1
          def m; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        # Comment A1
        # Comment A2
        # Comment A3
        class A
          # Comment a2
          attr_reader :a
          # Comment m1
          # Comment m2
          def m; end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        # Comment A1
        # Comment A2
        # Comment A3
        class A
          # Comment a1
          # Comment a2
          attr_reader :a

          # Comment m1
          # Comment m2
          def m; end
        end
      RBI
    end

    def test_merge_tree_comments_together
      tree1 = parse_rbi(<<~RBI)
        # typed: true

        # Some comments
      RBI

      tree2 = parse_rbi(<<~RBI)
        # typed: true

        # Other comments
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        # typed: true

        # Some comments
        # Other comments
      RBI
    end

    def test_merge_create_conflict_tree_for_scopes
      tree1 = parse_rbi(<<~RBI)
        class Foo
          A = T.let(T.unsafe(nil), T.untyped)
        end

        module Bar
          B = T.let(T.unsafe(nil), T.untyped)

          class Baz < Foo
            C = T.let(T.unsafe(nil), T.untyped)
          end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Foo
          A = T.let(T.unsafe(nil), T.untyped)
        end

        class Bar
          B = T.let(T.unsafe(nil), T.untyped)

          class Baz < Bar
            C = T.let(T.unsafe(nil), T.untyped)
          end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        <<<<<<< left
        class Foo
        =======
        module Foo
        >>>>>>> right
          A = T.let(T.unsafe(nil), T.untyped)
        end

        <<<<<<< left
        module Bar
        =======
        class Bar
        >>>>>>> right
          B = T.let(T.unsafe(nil), T.untyped)

          <<<<<<< left
          class Baz < Foo
          =======
          class Baz < Bar
          >>>>>>> right
            C = T.let(T.unsafe(nil), T.untyped)
          end
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_structs
      tree1 = parse_rbi(<<~RBI)
        A = Struct.new(:a) do
          def m; end
        end

        B = Struct.new(:b)

        C = Struct.new(:b, keyword_init: true) do
          def m; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        A = Struct.new(:a) do
          def m1; end
        end

        B = Struct.new(:x) do
          def m; end
        end

        C = Struct.new(:b) do
          def m; end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        A = ::Struct.new(:a) do
          def m; end
          def m1; end
        end

        <<<<<<< left
        B = ::Struct.new(:b) do
        =======
        B = ::Struct.new(:x) do
        >>>>>>> right
          def m; end
        end

        <<<<<<< left
        C = ::Struct.new(:b, keyword_init: true) do
        =======
        C = ::Struct.new(:b) do
        >>>>>>> right
          def m; end
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_constants
      tree1 = parse_rbi(<<~RBI)
        class Foo
          A = 10
          B = T.let(T.unsafe(nil), Integer)
          C = T.let(T.unsafe(nil), String)
        end
        A = 10
        B = T.let(T.unsafe(nil), Integer)
        C = T.let(T.unsafe(nil), String)
      RBI

      tree2 = parse_rbi(<<~RBI)
        class Foo
          A = 42
          B = T.let(T.unsafe(nil), String)
          C = T.let(T.unsafe(nil), String)
        end
        A = 42
        B = T.let(T.unsafe(nil), String)
        C = T.let(T.unsafe(nil), String)
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class Foo
          A = T.let(T.unsafe(nil), T.untyped)
          <<<<<<< left
          B = T.let(T.unsafe(nil), Integer)
          =======
          B = T.let(T.unsafe(nil), String)
          >>>>>>> right
          C = T.let(T.unsafe(nil), String)
        end

        A = T.let(T.unsafe(nil), T.untyped)
        <<<<<<< left
        B = T.let(T.unsafe(nil), Integer)
        =======
        B = T.let(T.unsafe(nil), String)
        >>>>>>> right
        C = T.let(T.unsafe(nil), String)
      RBI
    end

    def test_merge_create_conflict_tree_constants_and_scopes
      tree1 = parse_rbi(<<~RBI)
        class A; end
        module B; end
        module C; end
        class D < A; end
        module E
          module F; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module A; end
        class B; end
        C = 42
        class D; end
        module E::F; end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        <<<<<<< left
        class A; end
        =======
        module A; end
        >>>>>>> right
        <<<<<<< left
        module B; end
        =======
        class B; end
        >>>>>>> right
        <<<<<<< left
        module C; end
        =======
        C = T.let(T.unsafe(nil), T.untyped)
        >>>>>>> right
        <<<<<<< left
        class D < A; end
        =======
        class D; end
        >>>>>>> right

        module E
          module F; end
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_attributes
      tree1 = parse_rbi(<<~RBI)
        class Foo
          attr_accessor :a
          attr_accessor :b
          attr_accessor :c, :d
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class Foo
          attr_reader :a
          attr_writer :b
          attr_accessor :c
          attr_accessor :d
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class Foo
          <<<<<<< left
          attr_accessor :a
          attr_accessor :b
          attr_accessor :c, :d
          =======
          attr_reader :a
          attr_writer :b
          attr_accessor :c
          attr_accessor :d
          >>>>>>> right
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_methods
      tree1 = parse_rbi(<<~RBI)
        class Foo
          def m1; end
          def m2(a); end
          def m3(a); end
          def m4(a, b, c); end
          def m5(a = 10); end
          def m6(a); end
          def m7(&a); end
          def m8(a: nil); end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class Foo
          def m1(a); end
          def m2; end
          def m3(b); end
          def m4(c, b, a); end
          def m5(a); end
          def m6(a:); end
          def m7(a); end
          def m8(a: 10); end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class Foo
          <<<<<<< left
          def m1; end
          def m2(a); end
          def m3(a); end
          def m4(a, b, c); end
          def m5(a = 10); end
          def m6(a); end
          def m7(&a); end
          =======
          def m1(a); end
          def m2; end
          def m3(b); end
          def m4(c, b, a); end
          def m5(a); end
          def m6(a:); end
          def m7(a); end
          >>>>>>> right
          def m8(a: nil); end
        end
      RBI

      res = tree2.merge(tree1)
      assert_equal(<<~RBI, res.string)
        class Foo
          <<<<<<< left
          def m1(a); end
          def m2; end
          def m3(b); end
          def m4(c, b, a); end
          def m5(a); end
          def m6(a:); end
          def m7(a); end
          =======
          def m1; end
          def m2(a); end
          def m3(a); end
          def m4(a, b, c); end
          def m5(a = 10); end
          def m6(a); end
          def m7(&a); end
          >>>>>>> right
          def m8(a: 10); end
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_mixins
      tree1 = parse_rbi(<<~RBI)
        class A
          include A, B
          extend A, B
          mixes_in_class_methods A, B
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          include B
          extend B
          mixes_in_class_methods B
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          <<<<<<< left
          include A, B
          extend A, B
          mixes_in_class_methods A, B
          =======
          include B
          extend B
          mixes_in_class_methods B
          >>>>>>> right
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_sends
      tree1 = parse_rbi(<<~RBI)
        class A
          foo A
          bar :bar
          baz
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          foo B
          bar "bar"
          baz x
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A
          <<<<<<< left
          foo A
          bar :bar
          baz
          =======
          foo B
          bar "bar"
          baz x
          >>>>>>> right
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_tstructs
      tree1 = parse_rbi(<<~RBI)
        class A < T::Struct
          prop :a, Integer
          const :b, Integer
          prop :c, Integer
          const :d, Integer, default: 10
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A < T::Struct
          const :a, Integer
          prop :b, Integer
          prop :c, String
          const :d, Integer, default: 42
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class A < T::Struct
          <<<<<<< left
          prop :a, Integer
          const :b, Integer
          prop :c, Integer
          const :d, Integer, default: 10
          =======
          const :a, Integer
          prop :b, Integer
          prop :c, String
          const :d, Integer, default: 42
          >>>>>>> right
        end
      RBI
    end

    def test_merge_create_conflict_tree_for_signatures
      tree1 = parse_rbi(<<~RBI)
        class Foo
          sig { returns(Integer) }
          attr_reader :a

          sig { returns(Integer) }
          def m1; end

          sig { params(a: Integer).returns(Integer) }
          def m2(a); end

          sig { returns(Integer) }
          def m3; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class Foo
          sig { returns(String) }
          attr_reader :a

          sig { void }
          def m1; end

          sig { params(a: String).returns(Integer) }
          def m2(a); end

          sig { abstract.returns(Integer) }
          def m3; end
        end
      RBI

      res = tree1.merge(tree2)
      assert_equal(<<~RBI, res.string)
        class Foo
          <<<<<<< left
          sig { returns(Integer) }
          attr_reader :a

          sig { returns(Integer) }
          def m1; end

          sig { params(a: Integer).returns(Integer) }
          def m2(a); end

          sig { returns(Integer) }
          def m3; end
          =======
          sig { returns(String) }
          attr_reader :a

          sig { void }
          def m1; end

          sig { params(a: String).returns(Integer) }
          def m2(a); end

          sig { abstract.returns(Integer) }
          def m3; end
          >>>>>>> right
        end
      RBI
    end

    def test_merge_return_the_list_of_conflicts
      tree1 = parse_rbi(<<~RBI)
        class Foo
          A = T.let(T.unsafe(nil), T.untyped)
        end
        B = T.let(T.unsafe(nil), T.untyped)
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Foo
          A = T.let(T.unsafe(nil), String)
        end
        B = T.let(T.unsafe(nil), String)
      RBI

      merged_tree = tree1.merge(tree2)

      assert_equal(<<~STR.strip, merged_tree.conflicts.join("\n"))
        Conflicting definitions for `::Foo`
        Conflicting definitions for `::Foo::A`
        Conflicting definitions for `::B`
      STR
    end

    def test_merge_keep_left
      tree1 = parse_rbi(<<~RBI)
        module Foo
          A = T.let(T.unsafe(nil), T.untyped)

          class Bar
            def m1; end

            sig { void }
            def m2; end

            def m3; end
          end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Foo
          A = T.let(T.unsafe(nil), String)

          module Bar
            def m1(x); end

            sig { returns(Integer) }
            def m2; end

            def m4; end
          end
        end
      RBI

      res = tree1.merge(tree2, keep: Rewriters::Merge::Keep::LEFT)

      assert_equal(<<~RBI, res.string)
        module Foo
          A = T.let(T.unsafe(nil), T.untyped)

          class Bar
            def m1; end

            sig { void }
            def m2; end

            def m3; end
            def m4; end
          end
        end
      RBI
    end

    def test_merge_keep_right
      tree1 = parse_rbi(<<~RBI)
        module Foo
          A = T.let(T.unsafe(nil), T.untyped)

          class Bar
            def m1; end

            sig { void }
            def m2; end

            def m3; end
          end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Foo
          A = T.let(T.unsafe(nil), String)

          module Bar
            def m1(x); end

            sig { returns(Integer) }
            def m2; end

            def m4; end
          end
        end
      RBI

      res = tree1.merge(tree2, keep: Rewriters::Merge::Keep::RIGHT)

      assert_equal(<<~RBI, res.string)
        module Foo
          A = T.let(T.unsafe(nil), String)

          module Bar
            def m1(x); end

            sig { returns(Integer) }
            def m2; end

            def m3; end
            def m4; end
          end
        end
      RBI
    end

    def test_merge_trees_with_singleton_classes
      tree1 = parse_rbi(<<~RBI)
        module Foo
          class << self
            def m1; end

            sig { void }
            def m2; end
          end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Foo
          def self.m1(x); end

          sig { returns(Integer) }
          def self.m2; end
        end
      RBI

      res = tree1.merge(tree2, keep: Rewriters::Merge::Keep::RIGHT)

      assert_equal(<<~RBI, res.string)
        module Foo
          class << self
            def m1(x); end

            sig { returns(Integer) }
            def m2; end
          end
        end
      RBI
    end

    def test_merge_trees_with_singleton_classes_with_scope
      tree1 = parse_rbi(<<~RBI)
        module Foo
          def self.m1(x); end

          sig { returns(Integer) }
          def self.m2; end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        module Foo
          class << self
            def m1; end

            sig { void }
            def m2; end
          end
        end
      RBI

      res = tree1.merge(tree2, keep: Rewriters::Merge::Keep::RIGHT)

      assert_equal(<<~RBI, res.string)
        module Foo
          class << self
            def m1; end

            sig { void }
            def m2; end
          end
        end
      RBI
    end
  end
end
