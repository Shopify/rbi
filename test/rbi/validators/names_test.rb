# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Validators
    class NamesTest < Minitest::Test
      extend T::Sig

      sig { params(tree: Tree).returns(T::Array[Names::Error]) }
      def validate(tree)
        v = Validators::Names.new
        v.visit(tree)
        v.errors
      end

      def test_validate_names_empty_tree
        errors = validate(Tree.new)
        assert_empty(errors)
      end

      def test_validate_names_consts
        tree = Tree.new
        tree << Module.new("Foo")
        tree << Module.new("Foo::Bar::Baz")
        tree << Module.new("")
        tree << Module.new("foo")
        tree << Class.new("Foo")
        tree << Class.new("foo")
        tree << Const.new("T", "nil")
        tree << Const.new("foo", "nil")
        errors = validate(tree)
        assert_equal([
          "invalid name `` for Module",
          "invalid name `foo` for Module",
          "invalid name `foo` for Class",
          "invalid name `foo` for Const",
        ], errors.map(&:message))
      end

      def test_validate_names_methods
        tree = Tree.new
        tree << Method.new("foo")
        tree << Method.new("")
        tree << Method.new("0as")
        errors = validate(tree)
        assert_equal([
          "invalid name `` for Method",
          "invalid name `0as` for Method",
        ], errors.map(&:message))
      end

      def test_validate_names_params
        tree = Tree.new
        tree << Method.new("foo") do |meth|
          meth << ReqParam.new("foo")
          meth << ReqParam.new("")
          meth << ReqParam.new("a")
          meth << ReqParam.new("A")
          meth << OptParam.new("0a", "nil")
          meth << BlockParam.new("")
        end
        errors = validate(tree)
        assert_equal([
          "invalid name `` for ReqParam",
          "invalid name `A` for ReqParam",
          "invalid name `0a` for OptParam",
          "invalid name `` for BlockParam",
        ], errors.map(&:message))
      end

      def test_validate_names_attrs
        tree = Tree.new
        tree << AttrWriter.new(:foo)
        tree << AttrWriter.new(:"")
        tree << AttrWriter.new(:"foo")
        tree << AttrReader.new(:"foo bar")
        errors = validate(tree)
        assert_equal([
          "invalid name `` for AttrWriter",
          "invalid name `foo bar` for AttrReader",
        ], errors.map(&:message))
      end

      def test_validate_names_tstruct
        tree = Tree.new
        tree << TStruct.new("") do |tstruct|
          tstruct << TStructConst.new("a", "T")
          tstruct << TStructConst.new(" ", "T")
          tstruct << TStructProp.new("0", "T")
        end
        errors = validate(tree)
        assert_equal([
          "invalid name `` for TStruct",
          "invalid name ` ` for TStructConst",
          "invalid name `0` for TStructProp",
        ], errors.map(&:message))
      end

      def test_validate_names_tenum
        tree = Tree.new
        tree << TEnumBlock.new(["A", "", "_", "0", "a"])
        errors = validate(tree)
        assert_equal([
          "invalid name `` for TEnumBlock",
          "invalid name `_` for TEnumBlock",
          "invalid name `0` for TEnumBlock",
          "invalid name `a` for TEnumBlock",
        ], errors.map(&:message))
      end
    end
  end
end
