# typed: true
# frozen_string_literal: true

module RBI
  module Validators
    class ModelTest < Minitest::Test
      extend T::Sig

      def validate(tree)
        v = Validators::Model.new
        v.visit(tree)
        v.errors
      end

      def test_validate_empty
        errors = validate(Tree.new)
        assert_empty(errors)
      end

      def test_validate_scopes
        errors = validate(parse)
        assert_empty(errors)
      end
    end
  end
end
