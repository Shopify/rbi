# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class GroupNodesTest < Minitest::Test
    def test_group_nodes_in_tree
      rbi = Tree.new
      rbi << Const.new("C", "42")
      rbi << Module.new("S1")
      rbi << Class.new("S2")
      rbi << Struct.new("S3")
      rbi << Method.new("m1")
      rbi << Method.new("m2", is_singleton: true)
      rbi << Method.new("initialize")
      rbi << Extend.new("E")
      rbi << Include.new("I")
      rbi << MixesInClassMethods.new("MICM")
      rbi << Helper.new("h")
      rbi << TStructConst.new("SC", "Type")
      rbi << TStructProp.new("SP", "Type")
      rbi << TEnum.new("TE")
      rbi << SingletonClass.new
      rbi << TStruct.new("TS")
      rbi << Send.new("foo")
      rbi << AttrWriter.new(:baz, :b)
      rbi << AttrReader.new(:bar)
      rbi << AttrAccessor.new(:foo, :a, :z)
      rbi << RequiresAncestor.new("RA")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend E
        include I

        requires_ancestor { RA }

        h!

        mixes_in_class_methods MICM

        foo

        const :SC, Type
        prop :SP, Type

        attr_accessor :a, :foo, :z
        attr_writer :b, :baz
        attr_reader :bar

        def initialize; end

        def m1; end
        def self.m2; end

        class << self; end

        C = 42
        module S1; end
        class S2; end
        S3 = ::Struct.new
        class TE < T::Enum; end
        class TS < T::Struct; end
      RBI
    end

    def test_group_nested_nodes
      rbi = Tree.new

      scope1 = Class.new("Scope1")
      scope1 << Include.new("I1")
      scope1 << Method.new("m1")
      scope1 << Method.new("m2")
      scope1 << Send.new("foo")

      scope2 = Module.new("Scope2")
      scope2 << Const.new("C1", "42")
      scope2 << SingletonClass.new
      scope2 << Const.new("C2", "42")
      scope2 << Module.new("M1")

      scope3 = Struct.new("Scope3")
      scope3 << Extend.new("E1")
      scope3 << Extend.new("E2")
      scope3 << MixesInClassMethods.new("MICM1")
      scope3 << RequiresAncestor.new("RA1")

      rbi << scope1
      scope1 << scope2
      scope2 << scope3

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class Scope1
          include I1

          foo

          def m1; end
          def m2; end

          module Scope2
            class << self; end

            C1 = 42
            C2 = 42
            module M1; end

            Scope3 = ::Struct.new do
              extend E1
              extend E2

              requires_ancestor { RA1 }

              mixes_in_class_methods MICM1
            end
          end
        end
      RBI
    end

    def test_group_sort_nodes_in_groups
      rbi = Tree.new
      rbi << Const.new("C", "42")
      rbi << Module.new("S1")
      rbi << Class.new("S2")
      rbi << SingletonClass.new
      rbi << Struct.new("S3")
      rbi << Method.new("m1")
      rbi << Method.new("m2", is_singleton: true)
      rbi << Extend.new("E")
      rbi << Include.new("I")
      rbi << MixesInClassMethods.new("MICM")
      rbi << RequiresAncestor.new("RA")
      rbi << Helper.new("h")
      rbi << TStructConst.new("SC", "Type")
      rbi << TStructProp.new("SP", "Type")
      rbi << TEnum.new("TE")
      rbi << TStruct.new("TS")
      rbi << Send.new("foo")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend E
        include I

        requires_ancestor { RA }

        h!

        mixes_in_class_methods MICM

        foo

        const :SC, Type
        prop :SP, Type

        def m1; end
        def self.m2; end

        class << self; end

        C = 42
        module S1; end
        class S2; end
        S3 = ::Struct.new
        class TE < T::Enum; end
        class TS < T::Struct; end
      RBI
    end

    def test_group_does_not_sort_mixins
      rbi = Tree.new
      rbi << Include.new("I2")
      rbi << Extend.new("E2")
      rbi << MixesInClassMethods.new("M2")
      rbi << Include.new("I1")
      rbi << Extend.new("E1")
      rbi << MixesInClassMethods.new("M1")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        include I2
        extend E2
        include I1
        extend E1

        mixes_in_class_methods M2
        mixes_in_class_methods M1
      RBI
    end

    def test_group_does_not_sort_sends
      rbi = Tree.new
      rbi << Send.new("send4")
      rbi << Send.new("send2")
      rbi << Send.new("send3")
      rbi << Send.new("send1")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        send4
        send2
        send3
        send1
      RBI
    end

    def test_group_does_not_sort_type_members
      rbi = Tree.new
      rbi << TypeMember.new("T4", "type_member")
      rbi << TypeMember.new("T3", "type_template")
      rbi << TypeMember.new("T2", "type_member")
      rbi << TypeMember.new("T1", "type_template")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        T4 = type_member
        T3 = type_template
        T2 = type_member
        T1 = type_template
      RBI
    end

    def test_group_sort_nodes_in_scope
      rbi = Tree.new
      scope = Module.new("Scope")
      scope << Const.new("C", "42")
      scope << SingletonClass.new
      scope << Module.new("S1")
      scope << Class.new("S2")
      scope << Struct.new("S3")
      scope << Method.new("m1")
      scope << Method.new("m2", is_singleton: true)
      scope << Include.new("I")
      scope << Extend.new("E")
      scope << MixesInClassMethods.new("MICM")
      scope << RequiresAncestor.new("RA")
      scope << Helper.new("h")
      scope << TStructProp.new("SP", "Type")
      scope << TStructConst.new("SC", "Type")
      scope << TEnum.new("TE")
      scope << TStruct.new("TS")
      scope << TypeMember.new("TM2", "type_template")
      scope << TypeMember.new("TM1", "type_member")
      scope << Send.new("send2")
      scope << Send.new("send1")
      rbi << scope

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        module Scope
          include I
          extend E

          requires_ancestor { RA }

          h!

          TM2 = type_template
          TM1 = type_member

          mixes_in_class_methods MICM

          send2
          send1

          prop :SP, Type
          const :SC, Type

          def m1; end
          def self.m2; end

          class << self; end

          C = 42
          module S1; end
          class S2; end
          S3 = ::Struct.new
          class TE < T::Enum; end
          class TS < T::Struct; end
        end
      RBI
    end

    def test_group_sort_groups_in_tree
      rbi = Tree.new
      rbi << Const.new("C2", "42")
      rbi << SingletonClass.new
      rbi << Module.new("S2")
      rbi << Method.new("m2")
      rbi << Include.new("I2")
      rbi << Extend.new("E2")
      rbi << MixesInClassMethods.new("MICM2")
      rbi << RequiresAncestor.new("RA2")
      rbi << Helper.new("h2")
      rbi << TStructProp.new("SP2", "Type")
      rbi << TStructConst.new("SC2", "Type")
      rbi << TEnum.new("TE2")
      rbi << TStruct.new("TS2")
      rbi << Const.new("C1", "42")
      rbi << Class.new("S1")
      rbi << Method.new("m1")
      rbi << Include.new("I1")
      rbi << Extend.new("E1")
      rbi << MixesInClassMethods.new("MICM1")
      rbi << RequiresAncestor.new("RA1")
      rbi << Helper.new("h1")
      rbi << TStructProp.new("SP1", "Type")
      rbi << TStructConst.new("SC1", "Type")
      rbi << TEnum.new("TE1")
      rbi << TStruct.new("TS1")
      rbi << Struct.new("S3")
      rbi << TypeMember.new("TM2", "type_template")
      rbi << TypeMember.new("TM1", "type_member")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        include I2
        extend E2
        include I1
        extend E1

        requires_ancestor { RA1 }
        requires_ancestor { RA2 }

        h1!
        h2!

        TM2 = type_template
        TM1 = type_member

        mixes_in_class_methods MICM2
        mixes_in_class_methods MICM1

        prop :SP2, Type
        const :SC2, Type
        prop :SP1, Type
        const :SC1, Type

        def m1; end
        def m2; end

        class << self; end

        C1 = 42
        C2 = 42
        class S1; end
        module S2; end
        S3 = ::Struct.new
        class TE1 < T::Enum; end
        class TE2 < T::Enum; end
        class TS1 < T::Struct; end
        class TS2 < T::Struct; end
      RBI
    end

    def test_group_sort_nested_groups
      rbi = Tree.new

      sscope = Class.new("Scope2.1")
      sscope << Const.new("C2", "42")
      sscope << Module.new("S2")
      sscope << Method.new("m2")
      sscope << Include.new("I2")
      sscope << Extend.new("E2")
      sscope << MixesInClassMethods.new("MICM2")
      sscope << RequiresAncestor.new("RA2")
      sscope << Helper.new("h2")
      sscope << TStructProp.new("SP2", "Type")
      sscope << TStructConst.new("SC2", "Type")
      sscope << TEnum.new("TE2")
      sscope << TStruct.new("TS2")
      sscope << Const.new("C1", "42")
      sscope << Class.new("S1")
      sscope << Method.new("m1")
      sscope << Include.new("I1")
      sscope << Extend.new("E1")
      sscope << MixesInClassMethods.new("MICM1")
      sscope << RequiresAncestor.new("RA1")
      sscope << Helper.new("h1")
      sscope << TStructProp.new("SP1", "Type")
      sscope << TStructConst.new("SC1", "Type")
      sscope << TEnum.new("TE1")
      sscope << TStruct.new("TS1")
      sscope << Struct.new("S3")
      sscope << TypeMember.new("TM2", "type_template")
      sscope << TypeMember.new("TM1", "type_member")

      scope = Class.new("Scope2")
      scope << sscope
      scope << Const.new("C2", "42")
      scope << Module.new("S2")
      scope << Method.new("m2")
      scope << Include.new("I2")
      scope << Extend.new("E2")
      scope << MixesInClassMethods.new("MICM2")
      scope << RequiresAncestor.new("RA2")
      scope << Helper.new("h2")
      scope << TStructProp.new("SP2", "Type")
      scope << TStructConst.new("SC2", "Type")
      scope << TEnum.new("TE2")
      scope << TStruct.new("TS2")
      scope << Const.new("C1", "42")
      scope << Class.new("S1")
      scope << Method.new("m1")
      scope << Include.new("I1")
      scope << Extend.new("E1")
      scope << MixesInClassMethods.new("MICM1")
      scope << RequiresAncestor.new("RA1")
      scope << Helper.new("h1")
      scope << TStructProp.new("SP1", "Type")
      scope << TStructConst.new("SC1", "Type")
      scope << TEnum.new("TE1")
      scope << TStruct.new("TS1")
      scope << Struct.new("S3")
      scope << TypeMember.new("TM2", "type_template")
      scope << TypeMember.new("TM1", "type_member")
      rbi << scope

      scope = Class.new("Scope1")
      scope << Const.new("C2", "42")
      scope << Module.new("S2")
      scope << Method.new("m2")
      scope << Include.new("I2")
      scope << Extend.new("E2")
      scope << MixesInClassMethods.new("MICM2")
      scope << RequiresAncestor.new("RA2")
      scope << Helper.new("h2")
      scope << TStructProp.new("SP2", "Type")
      scope << TStructConst.new("SC2", "Type")
      scope << TEnum.new("TE2")
      scope << TStruct.new("TS2")
      scope << Const.new("C1", "42")
      scope << Class.new("S1")
      scope << Method.new("m1")
      scope << Include.new("I1")
      scope << Extend.new("E1")
      scope << MixesInClassMethods.new("MICM1")
      scope << RequiresAncestor.new("RA1")
      scope << Helper.new("h1")
      scope << TStructProp.new("SP1", "Type")
      scope << TStructConst.new("SC1", "Type")
      scope << TEnum.new("TE1")
      scope << TStruct.new("TS1")
      scope << Struct.new("S3")
      scope << TypeMember.new("TM2", "type_template")
      scope << TypeMember.new("TM1", "type_member")
      rbi << scope

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class Scope1
          include I2
          extend E2
          include I1
          extend E1

          requires_ancestor { RA1 }
          requires_ancestor { RA2 }

          h1!
          h2!

          TM2 = type_template
          TM1 = type_member

          mixes_in_class_methods MICM2
          mixes_in_class_methods MICM1

          prop :SP2, Type
          const :SC2, Type
          prop :SP1, Type
          const :SC1, Type

          def m1; end
          def m2; end

          C1 = 42
          C2 = 42
          class S1; end
          module S2; end
          S3 = ::Struct.new
          class TE1 < T::Enum; end
          class TE2 < T::Enum; end
          class TS1 < T::Struct; end
          class TS2 < T::Struct; end
        end

        class Scope2
          include I2
          extend E2
          include I1
          extend E1

          requires_ancestor { RA1 }
          requires_ancestor { RA2 }

          h1!
          h2!

          TM2 = type_template
          TM1 = type_member

          mixes_in_class_methods MICM2
          mixes_in_class_methods MICM1

          prop :SP2, Type
          const :SC2, Type
          prop :SP1, Type
          const :SC1, Type

          def m1; end
          def m2; end

          C1 = 42
          C2 = 42
          class S1; end
          module S2; end
          S3 = ::Struct.new

          class Scope2.1
            include I2
            extend E2
            include I1
            extend E1

            requires_ancestor { RA1 }
            requires_ancestor { RA2 }

            h1!
            h2!

            TM2 = type_template
            TM1 = type_member

            mixes_in_class_methods MICM2
            mixes_in_class_methods MICM1

            prop :SP2, Type
            const :SC2, Type
            prop :SP1, Type
            const :SC1, Type

            def m1; end
            def m2; end

            C1 = 42
            C2 = 42
            class S1; end
            module S2; end
            S3 = ::Struct.new
            class TE1 < T::Enum; end
            class TE2 < T::Enum; end
            class TS1 < T::Struct; end
            class TS2 < T::Struct; end
          end

          class TE1 < T::Enum; end
          class TE2 < T::Enum; end
          class TS1 < T::Struct; end
          class TS2 < T::Struct; end
        end
      RBI
    end

    def test_group_groups
      rbi = Tree.new
      rbi << Method.new("m")
      rbi << Include.new("I")
      rbi << AttrWriter.new(:a)

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        include I

        attr_writer :a

        def m; end
      RBI

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        include I

        attr_writer :a

        def m; end
      RBI
    end
  end
end
