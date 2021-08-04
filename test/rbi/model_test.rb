# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class ModelTest < Minitest::Test
    def test_model_block_builders
      rbi = RBI::File.new do |file|
        file << RBI::Tree.new do |tree|
          tree << RBI::Module.new("Foo") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Class.new("Bar") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::SingletonClass.new do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Const.new("C", "42") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::AttrAccessor.new(:a1) do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::AttrReader.new(:a2) do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::AttrWriter.new(:a3) do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Method.new("foo") do |node|
            node << RBI::ReqParam.new("p1") do |param|
              param.comments << Comment.new("comment")
            end
            node << RBI::OptParam.new("p2", "42") do |param|
              param.comments << Comment.new("comment")
            end
            node << RBI::RestParam.new("p3") do |param|
              param.comments << Comment.new("comment")
            end
            node << RBI::KwParam.new("p4") do |param|
              param.comments << Comment.new("comment")
            end
            node << RBI::KwOptParam.new("p5", "42") do |param|
              param.comments << Comment.new("comment")
            end
            node << RBI::KwRestParam.new("p6") do |param|
              param.comments << Comment.new("comment")
            end
            node << RBI::BlockParam.new("p7") do |param|
              param.comments << Comment.new("comment")
            end
            node.sigs << RBI::Sig.new do |sig|
              sig << RBI::SigParam.new("x", "T.untyped") do |param|
                param.comments << Comment.new("comment")
              end
            end
          end
          tree << RBI::Include.new("FOO") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Extend.new("FOO") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Public.new do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Protected.new do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::Private.new do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::TStruct.new("Struct") do |node|
            node << RBI::TStructConst.new("foo", "Foo") do |field|
              field.comments << Comment.new("comment")
            end
            node << RBI::TStructProp.new("foo", "Foo") do |field|
              field.comments << Comment.new("comment")
            end
          end
          tree << RBI::TEnum.new("Enum") do |node|
            node << RBI::TEnumBlock.new(["A", "B"]) do |block|
              block.comments << Comment.new("comment")
            end
          end
          tree << RBI::Helper.new("foo") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::TypeMember.new("foo", "type_member") do |node|
            node.comments << Comment.new("comment")
          end
          tree << RBI::MixesInClassMethods.new("FOO") do |node|
            node.comments << Comment.new("comment")
          end
        end
      end

      assert_equal(<<~RBI, rbi.string)
        # comment
        module Foo; end

        # comment
        class Bar; end

        # comment
        class << self; end

        # comment
        C = 42

        # comment
        attr_accessor :a1

        # comment
        attr_reader :a2

        # comment
        attr_writer :a3

        sig do
          params(
            x: T.untyped # comment
          ).void
        end
        def foo(
          p1, # comment
          p2 = 42, # comment
          *p3, # comment
          p4:, # comment
          p5: 42, # comment
          **p6, # comment
          &p7 # comment
        ); end

        # comment
        include FOO

        # comment
        extend FOO

        # comment
        public

        # comment
        protected

        # comment
        private

        class Struct < ::T::Struct
          # comment
          const :foo, Foo

          # comment
          prop :foo, Foo
        end

        class Enum < ::T::Enum
          # comment
          enums do
            A = new
            B = new
          end
        end

        # comment
        foo!

        # comment
        foo = type_member

        # comment
        mixes_in_class_methods FOO
      RBI
    end

    def test_model_fully_qualified_names
      mod = RBI::Module.new("Foo")
      assert_equal("::Foo", mod.fully_qualified_name)

      cls1 = RBI::Class.new("Bar")
      mod << cls1
      assert_equal("::Foo::Bar", cls1.fully_qualified_name)

      cls2 = RBI::Class.new("::Bar")
      mod << cls2
      assert_equal("::Bar", cls2.fully_qualified_name)

      singleton_class = RBI::SingletonClass.new
      cls1 << singleton_class
      assert_equal("::Foo::Bar::<self>", singleton_class.fully_qualified_name)

      const = RBI::Const.new("Foo", "42")
      assert_equal("::Foo", const.fully_qualified_name)

      mod << const
      assert_equal("::Foo::Foo", const.fully_qualified_name)

      const2 = RBI::Const.new("Foo::Bar", "42")
      assert_equal("::Foo::Bar", const2.fully_qualified_name)

      mod << const2
      assert_equal("::Foo::Foo::Bar", const2.fully_qualified_name)

      const3 = RBI::Const.new("::Foo::Bar", "42")
      assert_equal("::Foo::Bar", const3.fully_qualified_name)

      mod << const3
      assert_equal("::Foo::Bar", const3.fully_qualified_name)

      m1 = RBI::Method.new("m1")
      assert_equal("#m1", m1.fully_qualified_name)

      mod << m1
      assert_equal("::Foo#m1", m1.fully_qualified_name)

      m2 = RBI::Method.new("m2", is_singleton: true)
      assert_equal("::m2", m2.fully_qualified_name)

      mod << m2
      assert_equal("::Foo::m2", m2.fully_qualified_name)

      a1 = RBI::AttrReader.new(:m1)
      assert_equal(["#m1"], a1.fully_qualified_names)

      a2 = RBI::AttrWriter.new(:m2, :m3)
      mod << a2
      assert_equal(["::Foo#m2=", "::Foo#m3="], a2.fully_qualified_names)

      a3 = RBI::AttrAccessor.new(:m4, :m5)
      mod << a3
      assert_equal(["::Foo#m4", "::Foo#m4=", "::Foo#m5", "::Foo#m5="], a3.fully_qualified_names)

      struct = RBI::TStruct.new("Struct")
      mod << struct
      assert_equal("::Foo::Struct", struct.fully_qualified_name)

      sc = RBI::TStructConst.new("a", "A")
      struct << sc
      assert_equal(["::Foo::Struct#a"], sc.fully_qualified_names)

      sp = RBI::TStructProp.new("b", "B")
      struct << sp
      assert_equal(["::Foo::Struct#b", "::Foo::Struct#b="], sp.fully_qualified_names)

      enum = RBI::TEnum.new("Enum")
      mod << enum
      assert_equal("::Foo::Enum", enum.fully_qualified_name)

      type = RBI::TypeMember.new("T", "type_template")
      mod << type
      assert_equal("::Foo::T", type.fully_qualified_name)
    end

    def test_model_nodes_as_strings
      mod = RBI::Module.new("Foo")
      assert_equal("::Foo", mod.to_s)

      cls = RBI::Class.new("Bar")
      mod << cls
      assert_equal("::Foo::Bar", cls.to_s)

      singleton_class = RBI::SingletonClass.new
      cls << singleton_class
      assert_equal("::Foo::Bar::<self>", singleton_class.to_s)

      const = RBI::Const.new("Foo", "42")
      assert_equal("::Foo", const.to_s)

      mod << const
      assert_equal("::Foo::Foo", const.to_s)

      const2 = RBI::Const.new("Foo::Bar", "42")
      assert_equal("::Foo::Bar", const2.to_s)

      mod << const2
      assert_equal("::Foo::Foo::Bar", const2.to_s)

      m1 = RBI::Method.new("m1")
      mod << m1
      assert_equal("::Foo#m1()", m1.to_s)

      m2 = RBI::Method.new("m2", is_singleton: true)
      assert_equal("::m2()", m2.to_s)

      mod << m2
      assert_equal("::Foo::m2()", m2.to_s)

      m3 = RBI::Method.new("m3")
      m3 << RBI::ReqParam.new("a")
      m3 << RBI::OptParam.new("b", "42")
      m3 << RBI::RestParam.new("c")
      m3 << RBI::KwParam.new("d")
      m3 << RBI::KwOptParam.new("e", "42")
      m3 << RBI::KwRestParam.new("f")
      m3 << RBI::BlockParam.new("g")
      assert_equal("#m3(a, b, *c, d:, e:, **f:, &g)", m3.to_s)

      a1 = RBI::AttrReader.new(:m1)
      assert_equal(".attr_reader(:m1)", a1.to_s)

      a2 = RBI::AttrWriter.new(:m2, :m3)
      mod << a2
      assert_equal("::Foo.attr_writer(:m2, :m3)", a2.to_s)

      a3 = RBI::AttrAccessor.new(:m4, :m5)
      mod << a3
      assert_equal("::Foo.attr_accessor(:m4, :m5)", a3.to_s)

      struct = RBI::TStruct.new("Struct")
      mod << struct
      assert_equal("::Foo::Struct", struct.to_s)

      sc = RBI::TStructConst.new("a", "A")
      struct << sc
      assert_equal("::Foo::Struct.const(:a)", sc.to_s)

      sp = RBI::TStructProp.new("b", "B")
      struct << sp
      assert_equal("::Foo::Struct.prop(:b)", sp.to_s)

      enum = RBI::TEnum.new("Enum")
      mod << enum
      assert_equal("::Foo::Enum", enum.to_s)

      block = TEnumBlock.new(["A", "B"])
      enum << block
      assert_equal("::Foo::Enum.enums", block.to_s)

      type = RBI::TypeMember.new("T", "type_template")
      mod << type
      assert_equal("::Foo::T", type.to_s)

      inc = RBI::Include.new("A")
      mod << inc
      assert_equal("::Foo.include(A)", inc.to_s)

      ext = RBI::Extend.new("A", "B")
      mod << ext
      assert_equal("::Foo.extend(A, B)", ext.to_s)

      micm = RBI::MixesInClassMethods.new("A")
      mod << micm
      assert_equal("::Foo.mixes_in_class_methods(A)", micm.to_s)

      helper = RBI::Helper.new("foo")
      mod << helper
      assert_equal("::Foo.foo!", helper.to_s)
    end
  end
end
