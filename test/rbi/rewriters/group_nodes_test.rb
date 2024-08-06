# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class GroupNodesTest < Minitest::Test
    include TestHelper

    def test_group_nodes_in_tree
      tree = parse_rbi(<<~RBI)
        C = 42
        module S1; end
        class S2; end
        S3 = ::Struct.new
        def m1; end
        def self.m2; end
        def initialize; end
        extend E
        include I
        mixes_in_class_methods MICM
        abstract!
        const :SC, Type
        prop :SP, Type
        class TE < ::T::Enum; end
        class << self; end
        class TS < ::T::Struct; end
        foo
        attr_writer :baz, :b
        attr_reader :bar
        attr_accessor :foo, :a, :z
        requires_ancestor { RA }
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        extend E
        include I

        requires_ancestor { RA }

        abstract!

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
      tree = parse_rbi(<<~RBI)
        class Scope1
          include I1
          def m1; end
          def m2; end
          foo

          module Scope2
            C1 = 42
            class << self; end
            C2 = 42
            module M1; end

            Scope3 = ::Struct.new do
              extend E1
              extend E2
              mixes_in_class_methods MICM1
              requires_ancestor { RA1 }
            end
          end
        end
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
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
      tree = parse_rbi(<<~RBI)
        C = 42
        module S1; end
        class S2; end
        class << self; end
        S3 = ::Struct.new
        def m1; end
        def self.m2; end
        extend E
        include I
        mixes_in_class_methods MICM
        requires_ancestor { RA }
        abstract!
        const :SC, Type
        prop :SP, Type
        class TE < ::T::Enum; end
        class TS < ::T::Struct; end
        foo
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        extend E
        include I

        requires_ancestor { RA }

        abstract!

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
      tree = parse_rbi(<<~RBI)
        include I2
        extend E2
        mixes_in_class_methods M2
        include I1
        extend E1
        mixes_in_class_methods M1
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        include I2
        extend E2
        include I1
        extend E1

        mixes_in_class_methods M2
        mixes_in_class_methods M1
      RBI
    end

    def test_group_does_not_sort_sends
      tree = parse_rbi(<<~RBI)
        send4
        send2
        send3
        send1
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        send4
        send2
        send3
        send1
      RBI
    end

    def test_group_does_not_sort_type_members
      tree = parse_rbi(<<~RBI)
        T4 = type_member
        T3 = type_template
        T2 = type_member
        T1 = type_template
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        T4 = type_member
        T3 = type_template
        T2 = type_member
        T1 = type_template
      RBI
    end

    def test_group_sort_nodes_in_scope
      tree = parse_rbi(<<~RBI)
        module Scope
          C = 42
          class << self; end
          module S1; end
          class S2; end
          S3 = ::Struct.new
          def m1; end
          def self.m2; end
          include I
          extend E
          mixes_in_class_methods MICM
          requires_ancestor { RA }
          abstract!
          prop :SP, Type
          const :SC, Type
          class TE < ::T::Enum; end
          class TS < ::T::Struct; end
          TM2 = type_template
          TM1 = type_member
          send2
          send1
        end
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        module Scope
          include I
          extend E

          requires_ancestor { RA }

          abstract!

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
      tree = parse_rbi(<<~RBI)
        C2 = 42
        class << self; end
        module S2; end
        def m2; end
        include I2
        extend E2
        mixes_in_class_methods MICM2
        requires_ancestor { RA2 }
        sealed!
        prop :SP2, Type
        const :SC2, Type
        class TE2 < ::T::Enum; end
        class TS2 < ::T::Struct; end
        C1 = 42
        class S1; end
        def m1; end
        include I1
        extend E1
        mixes_in_class_methods MICM1
        requires_ancestor { RA1 }
        abstract!
        prop :SP1, Type
        const :SC1, Type
        class TE1 < ::T::Enum; end
        class TS1 < ::T::Struct; end
        S3 = ::Struct.new
        TM2 = type_template
        TM1 = type_member
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        include I2
        extend E2
        include I1
        extend E1

        requires_ancestor { RA1 }
        requires_ancestor { RA2 }

        abstract!
        sealed!

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
      tree = parse_rbi(<<~RBI)
        def m; end
        include I
        attr_writer :a
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        include I

        attr_writer :a

        def m; end
      RBI

      tree.group_nodes!
      tree.sort_nodes!

      assert_equal(<<~RBI, tree.string)
        include I

        attr_writer :a

        def m; end
      RBI
    end
  end
end
