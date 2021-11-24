# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class GroupNodesTest < Minitest::Test
    def test_group_nodes_in_tree
      rbi = RBI::Tree.new
      rbi << RBI::Const.new("C", "42")
      rbi << RBI::Module.new("S1")
      rbi << RBI::Class.new("S2")
      rbi << RBI::Struct.new("S3")
      rbi << RBI::Method.new("m1")
      rbi << RBI::Method.new("m2", is_singleton: true)
      rbi << RBI::Extend.new("E")
      rbi << RBI::Include.new("I")
      rbi << RBI::MixesInClassMethods.new("MICM")
      rbi << RBI::Helper.new("h")
      rbi << RBI::TStructConst.new("SC", "Type")
      rbi << RBI::TStructProp.new("SP", "Type")
      rbi << RBI::TEnum.new("TE")
      rbi << RBI::SingletonClass.new
      rbi << RBI::TStruct.new("TS")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend E
        include I

        h!

        mixes_in_class_methods MICM

        const :SC, Type
        prop :SP, Type

        def m1; end
        def self.m2; end

        class << self; end

        C = 42
        module S1; end
        class S2; end
        S3 = ::Struct.new
        class TE < ::T::Enum; end
        class TS < ::T::Struct; end
      RBI
    end

    def test_group_nested_nodes
      rbi = RBI::Tree.new

      scope1 = RBI::Class.new("Scope1")
      scope1 << RBI::Include.new("I1")
      scope1 << RBI::Method.new("m1")
      scope1 << RBI::Method.new("m2")

      scope2 = RBI::Module.new("Scope2")
      scope2 << RBI::Const.new("C1", "42")
      scope2 << RBI::SingletonClass.new
      scope2 << RBI::Const.new("C2", "42")
      scope2 << RBI::Module.new("M1")

      scope3 = RBI::Struct.new("Scope3")
      scope3 << RBI::Extend.new("E1")
      scope3 << RBI::Extend.new("E2")
      scope3 << RBI::MixesInClassMethods.new("MICM1")

      rbi << scope1
      scope1 << scope2
      scope2 << scope3

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class Scope1
          include I1

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

              mixes_in_class_methods MICM1
            end
          end
        end
      RBI
    end

    def test_group_sort_nodes_in_groups
      rbi = RBI::Tree.new
      rbi << RBI::Const.new("C", "42")
      rbi << RBI::Module.new("S1")
      rbi << RBI::Class.new("S2")
      rbi << RBI::SingletonClass.new
      rbi << RBI::Struct.new("S3")
      rbi << RBI::Method.new("m1")
      rbi << RBI::Method.new("m2", is_singleton: true)
      rbi << RBI::Extend.new("E")
      rbi << RBI::Include.new("I")
      rbi << RBI::MixesInClassMethods.new("MICM")
      rbi << RBI::Helper.new("h")
      rbi << RBI::TStructConst.new("SC", "Type")
      rbi << RBI::TStructProp.new("SP", "Type")
      rbi << RBI::TEnum.new("TE")
      rbi << RBI::TStruct.new("TS")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        extend E
        include I

        h!

        mixes_in_class_methods MICM

        const :SC, Type
        prop :SP, Type

        def m1; end
        def self.m2; end

        class << self; end

        C = 42
        module S1; end
        class S2; end
        S3 = ::Struct.new
        class TE < ::T::Enum; end
        class TS < ::T::Struct; end
      RBI
    end

    def test_group_does_not_sort_mixins
      rbi = RBI::Tree.new
      rbi << RBI::Include.new("I2")
      rbi << RBI::Extend.new("E2")
      rbi << RBI::MixesInClassMethods.new("M2")
      rbi << RBI::Include.new("I1")
      rbi << RBI::Extend.new("E1")
      rbi << RBI::MixesInClassMethods.new("M1")

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

    def test_group_does_not_sort_type_members
      rbi = RBI::Tree.new
      rbi << RBI::TypeMember.new("T4", "type_member")
      rbi << RBI::TypeMember.new("T3", "type_template")
      rbi << RBI::TypeMember.new("T2", "type_member")
      rbi << RBI::TypeMember.new("T1", "type_template")

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
      rbi = RBI::Tree.new
      scope = RBI::Module.new("Scope")
      scope << RBI::Const.new("C", "42")
      scope << RBI::SingletonClass.new
      scope << RBI::Module.new("S1")
      scope << RBI::Class.new("S2")
      scope << RBI::Struct.new("S3")
      scope << RBI::Method.new("m1")
      scope << RBI::Method.new("m2", is_singleton: true)
      scope << RBI::Include.new("I")
      scope << RBI::Extend.new("E")
      scope << RBI::MixesInClassMethods.new("MICM")
      scope << RBI::Helper.new("h")
      scope << RBI::TStructProp.new("SP", "Type")
      scope << RBI::TStructConst.new("SC", "Type")
      scope << RBI::TEnum.new("TE")
      scope << RBI::TStruct.new("TS")
      scope << RBI::TypeMember.new("TM2", "type_template")
      scope << RBI::TypeMember.new("TM1", "type_member")
      rbi << scope

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        module Scope
          include I
          extend E

          h!

          TM2 = type_template
          TM1 = type_member

          mixes_in_class_methods MICM

          const :SC, Type
          prop :SP, Type

          def m1; end
          def self.m2; end

          class << self; end

          C = 42
          module S1; end
          class S2; end
          S3 = ::Struct.new
          class TE < ::T::Enum; end
          class TS < ::T::Struct; end
        end
      RBI
    end

    def test_group_sort_groups_in_tree
      rbi = RBI::Tree.new
      rbi << RBI::Const.new("C2", "42")
      rbi << RBI::SingletonClass.new
      rbi << RBI::Module.new("S2")
      rbi << RBI::Method.new("m2")
      rbi << RBI::Include.new("I2")
      rbi << RBI::Extend.new("E2")
      rbi << RBI::MixesInClassMethods.new("MICM2")
      rbi << RBI::Helper.new("h2")
      rbi << RBI::TStructProp.new("SP2", "Type")
      rbi << RBI::TStructConst.new("SC2", "Type")
      rbi << RBI::TEnum.new("TE2")
      rbi << RBI::TStruct.new("TS2")
      rbi << RBI::Const.new("C1", "42")
      rbi << RBI::Class.new("S1")
      rbi << RBI::Method.new("m1")
      rbi << RBI::Include.new("I1")
      rbi << RBI::Extend.new("E1")
      rbi << RBI::MixesInClassMethods.new("MICM1")
      rbi << RBI::Helper.new("h1")
      rbi << RBI::TStructProp.new("SP1", "Type")
      rbi << RBI::TStructConst.new("SC1", "Type")
      rbi << RBI::TEnum.new("TE1")
      rbi << RBI::TStruct.new("TS1")
      rbi << RBI::Struct.new("S3")
      rbi << RBI::TypeMember.new("TM2", "type_template")
      rbi << RBI::TypeMember.new("TM1", "type_member")

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        include I2
        extend E2
        include I1
        extend E1

        h1!
        h2!

        TM2 = type_template
        TM1 = type_member

        mixes_in_class_methods MICM2
        mixes_in_class_methods MICM1

        const :SC1, Type
        const :SC2, Type
        prop :SP1, Type
        prop :SP2, Type

        def m1; end
        def m2; end

        class << self; end

        C1 = 42
        C2 = 42
        class S1; end
        module S2; end
        S3 = ::Struct.new
        class TE1 < ::T::Enum; end
        class TE2 < ::T::Enum; end
        class TS1 < ::T::Struct; end
        class TS2 < ::T::Struct; end
      RBI
    end

    def test_group_sort_nested_groups
      rbi = RBI::Tree.new

      sscope = RBI::Class.new("Scope2.1")
      sscope << RBI::Const.new("C2", "42")
      sscope << RBI::Module.new("S2")
      sscope << RBI::Method.new("m2")
      sscope << RBI::Include.new("I2")
      sscope << RBI::Extend.new("E2")
      sscope << RBI::MixesInClassMethods.new("MICM2")
      sscope << RBI::Helper.new("h2")
      sscope << RBI::TStructProp.new("SP2", "Type")
      sscope << RBI::TStructConst.new("SC2", "Type")
      sscope << RBI::TEnum.new("TE2")
      sscope << RBI::TStruct.new("TS2")
      sscope << RBI::Const.new("C1", "42")
      sscope << RBI::Class.new("S1")
      sscope << RBI::Method.new("m1")
      sscope << RBI::Include.new("I1")
      sscope << RBI::Extend.new("E1")
      sscope << RBI::MixesInClassMethods.new("MICM1")
      sscope << RBI::Helper.new("h1")
      sscope << RBI::TStructProp.new("SP1", "Type")
      sscope << RBI::TStructConst.new("SC1", "Type")
      sscope << RBI::TEnum.new("TE1")
      sscope << RBI::TStruct.new("TS1")
      sscope << RBI::Struct.new("S3")
      sscope << RBI::TypeMember.new("TM2", "type_template")
      sscope << RBI::TypeMember.new("TM1", "type_member")

      scope = RBI::Class.new("Scope2")
      scope << sscope
      scope << RBI::Const.new("C2", "42")
      scope << RBI::Module.new("S2")
      scope << RBI::Method.new("m2")
      scope << RBI::Include.new("I2")
      scope << RBI::Extend.new("E2")
      scope << RBI::MixesInClassMethods.new("MICM2")
      scope << RBI::Helper.new("h2")
      scope << RBI::TStructProp.new("SP2", "Type")
      scope << RBI::TStructConst.new("SC2", "Type")
      scope << RBI::TEnum.new("TE2")
      scope << RBI::TStruct.new("TS2")
      scope << RBI::Const.new("C1", "42")
      scope << RBI::Class.new("S1")
      scope << RBI::Method.new("m1")
      scope << RBI::Include.new("I1")
      scope << RBI::Extend.new("E1")
      scope << RBI::MixesInClassMethods.new("MICM1")
      scope << RBI::Helper.new("h1")
      scope << RBI::TStructProp.new("SP1", "Type")
      scope << RBI::TStructConst.new("SC1", "Type")
      scope << RBI::TEnum.new("TE1")
      scope << RBI::TStruct.new("TS1")
      scope << RBI::Struct.new("S3")
      scope << RBI::TypeMember.new("TM2", "type_template")
      scope << RBI::TypeMember.new("TM1", "type_member")
      rbi << scope

      scope = RBI::Class.new("Scope1")
      scope << RBI::Const.new("C2", "42")
      scope << RBI::Module.new("S2")
      scope << RBI::Method.new("m2")
      scope << RBI::Include.new("I2")
      scope << RBI::Extend.new("E2")
      scope << RBI::MixesInClassMethods.new("MICM2")
      scope << RBI::Helper.new("h2")
      scope << RBI::TStructProp.new("SP2", "Type")
      scope << RBI::TStructConst.new("SC2", "Type")
      scope << RBI::TEnum.new("TE2")
      scope << RBI::TStruct.new("TS2")
      scope << RBI::Const.new("C1", "42")
      scope << RBI::Class.new("S1")
      scope << RBI::Method.new("m1")
      scope << RBI::Include.new("I1")
      scope << RBI::Extend.new("E1")
      scope << RBI::MixesInClassMethods.new("MICM1")
      scope << RBI::Helper.new("h1")
      scope << RBI::TStructProp.new("SP1", "Type")
      scope << RBI::TStructConst.new("SC1", "Type")
      scope << RBI::TEnum.new("TE1")
      scope << RBI::TStruct.new("TS1")
      scope << RBI::Struct.new("S3")
      scope << RBI::TypeMember.new("TM2", "type_template")
      scope << RBI::TypeMember.new("TM1", "type_member")
      rbi << scope

      rbi.group_nodes!
      rbi.sort_nodes!

      assert_equal(<<~RBI, rbi.string)
        class Scope1
          include I2
          extend E2
          include I1
          extend E1

          h1!
          h2!

          TM2 = type_template
          TM1 = type_member

          mixes_in_class_methods MICM2
          mixes_in_class_methods MICM1

          const :SC1, Type
          const :SC2, Type
          prop :SP1, Type
          prop :SP2, Type

          def m1; end
          def m2; end

          C1 = 42
          C2 = 42
          class S1; end
          module S2; end
          S3 = ::Struct.new
          class TE1 < ::T::Enum; end
          class TE2 < ::T::Enum; end
          class TS1 < ::T::Struct; end
          class TS2 < ::T::Struct; end
        end

        class Scope2
          include I2
          extend E2
          include I1
          extend E1

          h1!
          h2!

          TM2 = type_template
          TM1 = type_member

          mixes_in_class_methods MICM2
          mixes_in_class_methods MICM1

          const :SC1, Type
          const :SC2, Type
          prop :SP1, Type
          prop :SP2, Type

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

            h1!
            h2!

            TM2 = type_template
            TM1 = type_member

            mixes_in_class_methods MICM2
            mixes_in_class_methods MICM1

            const :SC1, Type
            const :SC2, Type
            prop :SP1, Type
            prop :SP2, Type

            def m1; end
            def m2; end

            C1 = 42
            C2 = 42
            class S1; end
            module S2; end
            S3 = ::Struct.new
            class TE1 < ::T::Enum; end
            class TE2 < ::T::Enum; end
            class TS1 < ::T::Struct; end
            class TS2 < ::T::Struct; end
          end

          class TE1 < ::T::Enum; end
          class TE2 < ::T::Enum; end
          class TS1 < ::T::Struct; end
          class TS2 < ::T::Struct; end
        end
      RBI
    end
  end
end
