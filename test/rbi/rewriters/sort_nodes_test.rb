# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class SortNodesSpec < Minitest::Test
    def test_sorts_constants
      rbi = Tree.new
      rbi << Const.new("C", "42")
      rbi << Const.new("B", "42")
      rbi << Const.new("A", "42")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        A = 42
        B = 42
        C = 42
      RBI
    end

    def test_sort_modules
      rbi = Tree.new
      rbi << Module.new("C")
      rbi << Module.new("B")
      rbi << Module.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        module A; end
        module B; end
        module C; end
      RBI
    end

    def test_sort_classes
      rbi = Tree.new
      rbi << Class.new("C")
      rbi << Class.new("B")
      rbi << Class.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class A; end
        class B; end
        class C; end
      RBI
    end

    def test_sort_structs
      rbi = Tree.new
      rbi << Struct.new("C")
      rbi << Struct.new("B")
      rbi << Struct.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        A = ::Struct.new
        B = ::Struct.new
        C = ::Struct.new
      RBI
    end

    def test_sort_constants_and_keeps_original_order_in_case_of_conflicts
      rbi = Tree.new
      rbi << Class.new("B")
      rbi << Module.new("B")
      rbi << Const.new("B", "42")
      rbi << Const.new("A", "42")
      rbi << Module.new("A")
      rbi << Class.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        A = 42
        module A; end
        class A; end
        class B; end
        module B; end
        B = 42
      RBI
    end

    def test_sort_methods
      rbi = Tree.new
      rbi << Method.new("m4")
      rbi << Method.new("m3", is_singleton: true)
      rbi << Method.new("m2", is_singleton: true)
      rbi << Method.new("m1")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        def m1; end
        def m4; end
        def self.m2; end
        def self.m3; end
      RBI
    end

    def test_sort_does_not_sort_mixins
      rbi = Tree.new
      rbi << MixesInClassMethods.new("E")
      rbi << Extend.new("D")
      rbi << Include.new("C")
      rbi << Extend.new("B")
      rbi << Include.new("A")
      rbi << RequiresAncestor.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend D
        include C
        extend B
        include A
        requires_ancestor { A }
        mixes_in_class_methods E
      RBI
    end

    def test_does_not_sort_sends
      rbi = Tree.new
      rbi << Send.new("send4")
      rbi << Send.new("send2")
      rbi << Send.new("send3")
      rbi << Send.new("send1")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        send4
        send2
        send3
        send1
      RBI
    end

    def test_sort_helpers_test
      rbi = Tree.new
      rbi << Helper.new("c")
      rbi << Helper.new("b")
      rbi << Helper.new("a")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        a!
        b!
        c!
      RBI
    end

    def test_sort_struct_properties
      rbi = Tree.new
      rbi << TStructConst.new("d", "T")
      rbi << TStructProp.new("c", "T")
      rbi << TStructConst.new("b", "T")
      rbi << TStructProp.new("a", "T")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        const :d, T
        prop :c, T
        const :b, T
        prop :a, T
      RBI
    end

    def test_sort_tstructs
      rbi = Tree.new
      rbi << TStruct.new("D")
      rbi << TStruct.new("C")
      rbi << TStruct.new("B")
      rbi << TStruct.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class A < ::T::Struct; end
        class B < ::T::Struct; end
        class C < ::T::Struct; end
        class D < ::T::Struct; end
      RBI
    end

    def test_sort_enums
      rbi = Tree.new
      rbi << TEnum.new("D")
      rbi << TEnum.new("C")
      rbi << TEnum.new("B")
      rbi << TEnum.new("A")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class A < T::Enum; end
        class B < T::Enum; end
        class C < T::Enum; end
        class D < T::Enum; end
      RBI
    end

    def test_sort_does_nothing_if_all_nodes_are_already_sorted
      rbi = Tree.new
      rbi << Extend.new("M4")
      rbi << Include.new("M3")
      rbi << Extend.new("M2")
      rbi << Include.new("M1")
      rbi << Helper.new("h")
      rbi << MixesInClassMethods.new("MICM")
      rbi << TStructProp.new("SP1", "T")
      rbi << TStructConst.new("SP2", "T")
      rbi << TStructProp.new("SP3", "T")
      rbi << TStructConst.new("SP4", "T")
      rbi << Method.new("m1")
      rbi << Method.new("m2")
      rbi << Method.new("m3", is_singleton: true)
      rbi << Const.new("A", "42")
      rbi << Module.new("B")
      rbi << TEnum.new("C")
      rbi << TStruct.new("D")
      rbi << Class.new("E")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend M4
        include M3
        extend M2
        include M1
        h!
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
        class D < ::T::Struct; end
        class E; end
      RBI
    end

    def test_sort_all_nodes_in_tree
      rbi = Tree.new
      rbi << Const.new("A", "42")
      rbi << Extend.new("M4")
      rbi << Method.new("m1")
      rbi << MixesInClassMethods.new("MICM")
      rbi << Module.new("B")
      rbi << SingletonClass.new
      rbi << Include.new("M3")
      rbi << TStructConst.new("SP2", "T")
      rbi << Method.new("m2")
      rbi << TStruct.new("D")
      rbi << TEnum.new("C")
      rbi << SingletonClass.new
      rbi << Extend.new("M2")
      rbi << TStructConst.new("SP4", "T")
      rbi << Include.new("M1")
      rbi << Helper.new("h")
      rbi << SingletonClass.new
      rbi << Class.new("E")
      rbi << TStructProp.new("SP1", "T")
      rbi << Method.new("m3", is_singleton: true)
      rbi << TStructProp.new("SP3", "T")
      rbi << AttrWriter.new(:baz, :b)
      rbi << AttrReader.new(:bar)
      rbi << AttrAccessor.new(:foo, :a, :z)
      rbi << RequiresAncestor.new("RA")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend M4
        include M3
        extend M2
        include M1
        requires_ancestor { RA }
        h!
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
        A = 42
        module B; end
        class C < T::Enum; end
        class D < ::T::Struct; end
        class E; end
      RBI
    end

    def test_sort_doesnt_change_privacy
      rbi = Tree.new
      rbi << Public.new
      rbi << Method.new("c") # 0
      rbi << Private.new     # 1
      rbi << Method.new("a") # 2
      rbi << Protected.new   # 3
      rbi << Method.new("b") # 4
      rbi << Public.new
      rbi << Method.new("aa")

      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
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
