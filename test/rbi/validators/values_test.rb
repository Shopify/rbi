# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Validators
    class TypesTest < Minitest::Test
      extend T::Sig

      sig { params(tree: Tree).returns(T::Array[Types::Error]) }
      def validate(tree)
        v = Validators::Types.new
        v.visit(tree)
        v.errors
      end

      def test_validate_values_empty_tree
        errors = validate(Tree.new)
        assert_empty(errors)
      end

      def test_validate_values_consts
        tree = Tree.new
        errors = validate(tree)
        assert_equal([
          "invalid name `` for Module",
        ], errors.map(&:message))
      end

      def test_validate_values_params
        tree = Tree.new
        errors = validate(tree)
        assert_equal([
          "invalid name `0as` for Method",
        ], errors.map(&:message))
      end
    end
  end
end
