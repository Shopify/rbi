# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class SortNodesSpec < Minitest::Test
    include TestHelper

    def test_sorts_constants
      tree = parse_rbi(<<~RBI)
        C = 42
        B = 42
        A = 42
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        A = T.let(T.unsafe(nil), T.untyped)
        B = T.let(T.unsafe(nil), T.untyped)
        C = T.let(T.unsafe(nil), T.untyped)
      RBI
    end

    def test_sort_modules
      tree = parse_rbi(<<~RBI)
        module C; end
        module B; end
        module A; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        module A; end
        module B; end
        module C; end
      RBI
    end

    def test_sort_classes
      tree = parse_rbi(<<~RBI)
        class C; end
        class B; end
        class A; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        class A; end
        class B; end
        class C; end
      RBI
    end

    def test_sort_structs
      tree = parse_rbi(<<~RBI)
        C = ::Struct.new
        B = ::Struct.new
        A = ::Struct.new
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        A = ::Struct.new
        B = ::Struct.new
        C = ::Struct.new
      RBI
    end

    def test_sort_constants_and_keeps_original_order_in_case_of_conflicts
      tree = parse_rbi(<<~RBI)
        class B; end
        module B; end
        B = 42
        A = 42
        module A; end
        class A; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        A = T.let(T.unsafe(nil), T.untyped)
        module A; end
        class A; end
        class B; end
        module B; end
        B = T.let(T.unsafe(nil), T.untyped)
      RBI
    end

    def test_sort_methods
      tree = parse_rbi(<<~RBI)
        def m4; end
        def self.m3; end
        def self.m2; end
        def m1; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        def m1; end
        def m4; end
        def self.m2; end
        def self.m3; end
      RBI
    end

    def test_sort_does_not_sort_mixins
      tree = parse_rbi(<<~RBI)
        mixes_in_class_methods E
        extend D
        include C
        extend B
        include A
        requires_ancestor { A }
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        extend D
        include C
        extend B
        include A
        requires_ancestor { A }
        mixes_in_class_methods E
      RBI
    end

    def test_does_not_sort_sends
      tree = parse_rbi(<<~RBI)
        send4
        send2
        send3
        send1
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        send4
        send2
        send3
        send1
      RBI
    end

    def test_sort_helpers_test
      tree = parse_rbi(<<~RBI)
        sealed!
        abstract!
        interface!
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        abstract!
        interface!
        sealed!
      RBI
    end

    def test_sort_struct_properties
      tree = parse_rbi(<<~RBI)
        const :d, T
        prop :c, T
        const :b, T
        prop :a, T
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        const :d, T
        prop :c, T
        const :b, T
        prop :a, T
      RBI
    end

    def test_sort_tstructs
      tree = parse_rbi(<<~RBI)
        class D < ::T::Struct; end
        class C < ::T::Struct; end
        class B < ::T::Struct; end
        class A < ::T::Struct; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        class A < T::Struct; end
        class B < T::Struct; end
        class C < T::Struct; end
        class D < T::Struct; end
      RBI
    end

    def test_sort_enums
      tree = parse_rbi(<<~RBI)
        class D < ::T::Enum; end
        class C < ::T::Enum; end
        class B < ::T::Enum; end
        class A < ::T::Enum; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        class A < T::Enum; end
        class B < T::Enum; end
        class C < T::Enum; end
        class D < T::Enum; end
      RBI
    end

    def test_sort_does_nothing_if_all_nodes_are_already_sorted
      tree = parse_rbi(<<~RBI)
        extend M4
        include M3
        extend M2
        include M1
        abstract!
        mixes_in_class_methods MICM
        prop :SP1, T
        const :SP2, T
        prop :SP3, T
        const :SP4, T
        def m1; end
        def m2; end
        def self.m3; end
        A = 42
        module B; end
        class C < T::Enum; end
        class D < T::Struct; end
        class E; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        extend M4
        include M3
        extend M2
        include M1
        abstract!
        mixes_in_class_methods MICM
        prop :SP1, T
        const :SP2, T
        prop :SP3, T
        const :SP4, T
        def m1; end
        def m2; end
        def self.m3; end
        A = T.let(T.unsafe(nil), T.untyped)
        module B; end
        class C < T::Enum; end
        class D < T::Struct; end
        class E; end
      RBI
    end

    def test_sort_all_nodes_in_tree
      tree = parse_rbi(<<~RBI)
        A = 42
        extend M4
        def m1; end
        mixes_in_class_methods MICM
        module B; end
        class << self; end
        include M3
        const :SP2, T
        def m2; end
        class D < T::Struct; end
        class C < T::Enum; end
        class << self; end
        extend M2
        const :SP4, T
        include M1
        abstract!
        class << self; end
        class E; end
        prop :SP1, T
        def self.m3; end
        prop :SP3, T
        attr_writer :baz, :b
        attr_reader :bar
        attr_accessor :foo, :a, :z
        requires_ancestor { RA }
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        extend M4
        include M3
        extend M2
        include M1
        requires_ancestor { RA }
        abstract!
        mixes_in_class_methods MICM
        const :SP2, T
        const :SP4, T
        prop :SP1, T
        prop :SP3, T
        attr_accessor :a, :foo, :z
        attr_writer :b, :baz
        attr_reader :bar
        def m1; end
        def m2; end
        def self.m3; end
        class << self; end
        class << self; end
        class << self; end
        A = T.let(T.unsafe(nil), T.untyped)
        module B; end
        class C < T::Enum; end
        class D < T::Struct; end
        class E; end
      RBI
    end

    def test_sort_doesnt_change_privacy
      tree = parse_rbi(<<~RBI)
        public
        def c; end
        private
        def a; end
        protected
        def b; end
        public
        def aa; end
      RBI

      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        public
        def c; end
        private
        def a; end
        protected
        def b; end
        public
        def aa; end
      RBI
    end
  end
end
