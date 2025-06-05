# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class TypeSimplifyTest < Minitest::Test
    def test_normalize_simple
      assert_equal(
        parse_type("Foo"),
        parse_and_normalize("Foo"),
      )

      assert_equal(
        parse_type("Foo::Bar"),
        parse_and_normalize("Foo::Bar"),
      )
    end

    def test_simplify_simple
      assert_equal(
        parse_type("Foo"),
        parse_and_simplify("Foo"),
      )

      assert_equal(
        parse_type("Foo::Bar"),
        parse_and_simplify("Foo::Bar"),
      )
    end

    def test_normalize_anything
      assert_equal(
        parse_type("T.anything"),
        parse_and_normalize("T.anything"),
      )
    end

    def test_simplify_anything
      assert_equal(
        parse_type("T.anything"),
        parse_and_simplify("T.anything"),
      )
    end

    def test_normalize_attached_class
      assert_equal(
        parse_type("T.attached_class"),
        parse_and_normalize("T.attached_class"),
      )
    end

    def test_simplify_attached_class
      assert_equal(
        parse_type("T.attached_class"),
        parse_and_simplify("T.attached_class"),
      )
    end

    def test_normalize_boolean
      assert_equal(
        parse_type("T.any(TrueClass, FalseClass)"),
        parse_and_normalize("T::Boolean"),
      )
    end

    def test_simplify_boolean
      assert_equal(
        parse_type("T::Boolean"),
        parse_and_simplify("T::Boolean"),
      )
    end

    def test_normalize_noreturn
      assert_equal(
        parse_type("T.noreturn"),
        parse_and_normalize("T.noreturn"),
      )
    end

    def test_simplify_noreturn
      assert_equal(
        parse_type("T.noreturn"),
        parse_and_simplify("T.noreturn"),
      )
    end

    def test_normalize_self_type
      assert_equal(
        parse_type("T.self_type"),
        parse_and_normalize("T.self_type"),
      )
    end

    def test_simplify_self_type
      assert_equal(
        parse_type("T.self_type"),
        parse_and_simplify("T.self_type"),
      )
    end

    def test_normalize_untyped
      assert_equal(
        parse_type("T.untyped"),
        parse_and_normalize("T.untyped"),
      )
    end

    def test_simplify_untyped
      assert_equal(
        parse_type("T.untyped"),
        parse_and_simplify("T.untyped"),
      )
    end

    def test_normalize_void
      assert_equal(
        parse_type("void"),
        parse_and_normalize("void"),
      )
    end

    def test_simplify_void
      assert_equal(
        parse_type("void"),
        parse_and_simplify("void"),
      )
    end

    def test_normalize_class
      assert_equal(
        parse_type("T::Class[String]"),
        parse_and_normalize("T::Class[String]"),
      )
    end

    def test_simplify_class
      assert_equal(
        parse_type("T::Class[String]"),
        parse_and_simplify("T::Class[String]"),
      )
    end

    def test_normalize_class_of
      assert_equal(
        parse_type("T.class_of(String)"),
        parse_and_normalize("T.class_of(String)"),
      )
    end

    def test_simplify_class_of
      assert_equal(
        parse_type("T.class_of(String)"),
        parse_and_simplify("T.class_of(String)"),
      )
    end

    def test_normalize_nilable
      assert_equal(
        parse_type("T.any(NilClass, String)"),
        parse_and_normalize("T.nilable(String)"),
      )
    end

    def test_simplify_nilable
      assert_equal(
        parse_type("T.nilable(String)"),
        parse_and_simplify("T.nilable(String)"),
      )
    end

    def test_simplify_nilable_to_untyped
      assert_equal(
        parse_type("T.untyped"),
        parse_and_simplify("T.nilable(T.untyped)"),
      )
    end

    def test_simplify_nilable_nilable
      assert_equal(
        parse_type("T.nilable(X)"),
        parse_and_simplify("T.nilable(T.nilable(X))"),
      )
    end

    def test_simplify_nilable_nested
      assert_equal(
        parse_type("T.nilable(X)"),
        parse_and_simplify("T.nilable(T.nilable(T.nilable(T.nilable(X))))"),
      )
    end

    def test_normalize_all
      assert_equal(
        parse_type("T.all(String, Integer)"),
        parse_and_normalize("T.all(String, Integer)"),
      )
    end

    def test_normalize_all_single_type
      assert_equal(
        parse_type("Integer"),
        parse_and_normalize("T.all(Integer, Integer, Integer)"),
      )
    end

    def test_normalize_all_dedup
      assert_equal(
        parse_type("T.all(X, Y, Z)"),
        parse_and_normalize("T.all(X, Y, Z, X, Y, Z, X, Y, Z)"),
      )
    end

    def test_normalize_all_nested
      assert_equal(
        parse_type("T.all(X, Y, Z)"),
        parse_and_normalize("T.all(T.all(X, Y), Z)"),
      )
    end

    def test_normalize_all_nested_deep
      assert_equal(
        parse_type("T.all(X, Y, Z)"),
        parse_and_normalize("T.all(T.all(T.all(X, Y), Z), T.all(X, Y, Z))"),
      )
    end

    def test_normalize_all_nested_nilable
      assert_equal(
        parse_type("T.all(T.any(NilClass, X), Y, Z)"),
        parse_and_normalize("T.all(T.nilable(X), Y, Z)"),
      )
    end

    def test_normalize_all_nested_boolean
      assert_equal(
        parse_type("T.all(X, Y, T.any(TrueClass, FalseClass))"),
        parse_and_normalize("T.all(X, Y, T::Boolean)"),
      )
    end

    def test_simplify_all
      assert_equal(
        parse_type("T.all(X, Y, Z)"),
        parse_and_simplify("T.all(T.all(X, Y), Z)"),
      )
    end

    def test_simplify_all_nested_any_nilable
      assert_equal(
        parse_type("T.all(T.nilable(X), Y, Z)"),
        parse_and_simplify("T.all(T.any(NilClass, X), Y, Z)"),
      )
    end

    def test_simplify_all_nested_any_boolean
      assert_equal(
        parse_type("T.all(X, Y, T::Boolean)"),
        parse_and_simplify("T.all(X, Y, T.any(TrueClass, FalseClass))"),
      )
    end

    def test_normalize_any_dedup
      assert_equal(
        parse_type("T.any(X, Y, Z)"),
        parse_and_normalize("T.any(X, Y, Z, X, Y, Z, X, Y, Z)"),
      )
    end

    def test_normalize_any_dedup_to_single
      assert_equal(
        parse_type("X"),
        parse_and_normalize("T.any(X, X, X)"),
      )
    end

    def test_normalize_any_nested
      assert_equal(
        parse_type("T.any(X, Y, Z)"),
        parse_and_normalize("T.any(T.any(X, Y), Z)"),
      )
    end

    def test_normalize_any_nested_deep
      assert_equal(
        parse_type("T.any(X, Y, Z)"),
        parse_and_normalize("T.any(T.any(T.any(X, Y), Z), T.any(X, Y, Z))"),
      )
    end

    def test_normalize_any_nested_nilable
      assert_equal(
        parse_type("T.any(NilClass, X, Y, Z)"),
        parse_and_normalize("T.any(T.nilable(X), Y, Z)"),
      )
    end

    def test_normalize_any_nested_boolean
      assert_equal(
        parse_type("T.any(X, Y, TrueClass, FalseClass)"),
        parse_and_normalize("T.any(X, Y, T::Boolean)"),
      )
    end

    def test_simplify_any
      assert_equal(
        parse_type("T.any(X, Y, Z)"),
        parse_and_simplify("T.any(T.any(X, Y), Z)"),
      )
    end

    def test_simplify_any_to_untyped
      assert_equal(
        parse_type("T.untyped"),
        parse_and_simplify("T.any(T.untyped, X, Y, Z)"),
      )
    end

    def test_simplify_any_to_untyped_nested
      assert_equal(
        parse_type("T.untyped"),
        parse_and_simplify("T.any(T.any(T.untyped, X), Y, Z)"),
      )
    end

    def test_simplify_any_to_boolean
      assert_equal(
        parse_type("T::Boolean"),
        parse_and_simplify("T.any(TrueClass, FalseClass)"),
      )
    end

    def test_simplify_any_with_boolean
      assert_equal(
        parse_type("T.any(X, Y, Z, T::Boolean)"),
        parse_and_simplify("T.any(TrueClass, FalseClass, X, Y, Z)"),
      )
    end

    def test_simplify_any_nilclass_to_nilable
      assert_equal(
        parse_type("T.nilable(T.any(X, Y, Z))"),
        parse_and_simplify("T.any(NilClass, X, Y, Z)"),
      )
    end

    def test_simplify_any_nilclass_to_nilable_nested
      assert_equal(
        parse_type("T.nilable(T.any(X, Y, Z))"),
        parse_and_simplify("T.any(T.any(NilClass, X), Y, Z)"),
      )
    end

    def test_simplify_any_nilclass_to_nilable_nested2
      assert_equal(
        parse_type("T.nilable(T.any(X, Y, Z))"),
        parse_and_simplify("T.any(T.any(X, Y, T.any(Z, NilClass)), Z)"),
      )
    end

    def test_normalize_generic
      assert_equal(
        parse_type("Foo[String, Integer]"),
        parse_and_normalize("Foo[String, Integer]"),
      )
    end

    def test_simplify_generic
      assert_equal(
        parse_type("Foo[String, Integer]"),
        parse_and_simplify("Foo[String, Integer]"),
      )
    end

    def test_normalize_type_parameter
      assert_equal(
        parse_type("T.type_parameter(:A)"),
        parse_and_normalize("T.type_parameter(:A)"),
      )
    end

    def test_simplify_type_parameter
      assert_equal(
        parse_type("T.type_parameter(:A)"),
        parse_and_simplify("T.type_parameter(:A)"),
      )
    end

    def test_normalize_tuple
      assert_equal(
        parse_type("[String, Integer, Integer]"),
        parse_and_normalize("[String, Integer, Integer]"),
      )
    end

    def test_simplify_tuple
      assert_equal(
        parse_type("[String, Integer, Integer]"),
        parse_and_simplify("[String, Integer, Integer]"),
      )
    end

    def test_normalize_shape
      assert_equal(
        parse_type("{name: String, age: Integer}"),
        parse_and_normalize("{name: String, age: Integer}"),
      )
    end

    def test_simplify_shape
      assert_equal(
        parse_type("{name: String, age: Integer}"),
        parse_and_simplify("{name: String, age: Integer}"),
      )
    end

    def test_normalize_proc
      assert_equal(
        parse_type("T.proc.void"),
        parse_and_normalize("T.proc.void"),
      )
    end

    def test_simplify_proc
      assert_equal(
        parse_type("T.proc.void"),
        parse_and_simplify("T.proc.void"),
      )
    end

    private

    #: (String) -> String
    def parse_type(string)
      Type.parse_string(string).to_rbi
    end

    #: (String) -> String
    def parse_and_normalize(string)
      Type.parse_string(string).normalize.to_rbi
    end

    #: (String) -> String
    def parse_and_simplify(string)
      Type.parse_string(string).simplify.to_rbi
    end
  end
end
