# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class TypeTest < Minitest::Test
    def test_build_cant_call_new
      exception = assert_raises(NoMethodError) do
        Type::Simple.new("String")
      end

      assert_equal("protected method `new' called for RBI::Type::Simple:Class", exception.message)
    end

    def test_build_type_simple_raises_if_incorrect_name
      Type.simple("String")
      Type.simple("::String")
      Type.simple("String::String")
      Type.simple("S1_1::S1_1")

      exception = assert_raises(NameError) do
        Type.simple("T.nilable(String)")
      end

      assert_equal("Invalid type name: T.nilable(String)", exception.message)

      exception = assert_raises(NameError) do
        Type.simple("String[Integer]")
      end

      assert_equal("Invalid type name: String[Integer]", exception.message)

      exception = assert_raises(NameError) do
        Type.simple("<< String")
      end

      assert_equal("Invalid type name: << String", exception.message)
    end

    def test_build_type_string
      type = Type.simple("String")
      refute_predicate(type, :nilable?)
      assert_equal("String", type.to_rbi)
    end

    def test_build_type_verbatim
      type = Type.verbatim("Foo/bar/baz@fizz-buzz")
      refute_predicate(type, :nilable?)
      assert_equal("Foo/bar/baz@fizz-buzz", type.to_rbi)
    end

    def test_build_type_anything
      type = Type.anything
      assert_equal("T.anything", type.to_rbi)
    end

    def test_build_type_void
      type = Type.void
      assert_equal("void", type.to_rbi)
    end

    def test_build_type_nilable
      type = Type.simple("String")
      refute_predicate(type, :nilable?)
      assert_equal("String", type.to_rbi)

      type = type.nilable
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(String)", type.to_rbi)
    end

    def test_build_type_nilable_of_untyped
      type = Type.nilable(Type.untyped)
      assert_instance_of(Type::Untyped, type)
      assert_equal("T.untyped", type.to_rbi)
    end

    def test_build_type_nilable_of_nilable
      type = Type.nilable(Type.nilable(Type.simple("String")))
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(String)", type.to_rbi)
    end

    def test_build_type_all
      type = Type.all(
        Type.simple("String"),
        Type.simple("Integer"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("T.all(String, Integer)", type.to_rbi)
    end

    def test_build_type_all_of_all
      type = Type.all(
        Type.simple("String"),
        Type.simple("Integer"),
        Type.all(
          Type.simple("Numeric"),
          Type.simple("Integer")
        )
      )
      assert_instance_of(Type::All, type)
      assert_equal("T.all(String, Integer, Numeric)", type.to_rbi)
    end

    def test_build_type_all_of_dup
      type = Type.all(
        Type.simple("String"),
        Type.simple("String"),
      )
      assert_instance_of(Type::Simple, type)
      assert_equal("String", type.to_rbi)
    end

    def test_build_type_any
      type = Type.any(
        Type.simple("String"),
        Type.simple("Integer")
      )
      refute_predicate(type, :nilable?)
      assert_equal("T.any(String, Integer)", type.to_rbi)

      type = Type.any(
        Type.simple("String"),
        Type.simple("String"),
        Type.simple("Integer"),
        Type.simple("Integer")
      )
      refute_predicate(type, :nilable?)
      assert_equal("T.any(String, Integer)", type.to_rbi)
    end

    def test_build_type_any_of_any
      type = Type.any(
        Type.any(
          Type.simple("String"),
          Type.simple("Integer")
        ),
        Type.any(
          Type.simple("String"),
          Type.simple("Symbol")
        )
      )

      assert_instance_of(Type::Any, type)
      assert_equal("T.any(String, Integer, Symbol)", type.to_rbi)
    end

    def test_build_type_any_of_any_of_any
      type = Type.any(
        Type.any(
          Type.simple("String"),
          Type.simple("Integer")
        ),
        Type.any(
          Type.simple("Numeric"),
          Type.any(
            Type.simple("String"),
            Type.simple("Symbol")
          )
        )
      )

      assert_instance_of(Type::Any, type)
      assert_equal("T.any(String, Integer, Numeric, Symbol)", type.to_rbi)
    end

    def test_build_type_any_of_uniq
      type = Type.any(
        Type.simple("String"),
        Type.simple("String"),
      )
      assert_instance_of(Type::Simple, type)
      assert_equal("String", type.to_rbi)
    end

    def test_build_type_any_of_uniq_and_nilable
      type = Type.any(
        Type.simple("String"),
        Type.simple("String"),
        Type.nilable(Type.simple("String")),
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(String)", type.to_rbi)
    end

    def test_build_type_any_of_nilclass
      type = Type.any(
        Type.simple("String"),
        Type.simple("NilClass")
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(String)", type.to_rbi)
    end

    def test_build_type_any_of_nilable
      type = Type.any(
        Type.simple("String"),
        Type.nilable(Type.simple("Integer")),
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T.any(String, Integer))", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass
      type = Type.any(
        Type.simple("TrueClass"),
        Type.simple("String"),
        Type.simple("FalseClass")
      )
      assert_equal("T.any(String, T::Boolean)", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass_and_nilclass
      type = Type.any(
        Type.simple("TrueClass"),
        Type.simple("NilClass"),
        Type.simple("FalseClass")
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T::Boolean)", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass_with_nilable
      type = Type.any(
        Type.simple("TrueClass"),
        Type.nilable(Type.simple("FalseClass"))
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T::Boolean)", type.to_rbi)
    end

    def test_build_type_generic
      type = Type.generic("T::Array", Type.simple("String"))
      refute_predicate(type, :nilable?)
      assert_equal("T::Array[String]", type.to_rbi)

      type = Type.generic("T::Hash", Type.simple("Integer"), Type.simple("String"))
      refute_predicate(type, :nilable?)
      assert_equal("T::Hash[Integer, String]", type.to_rbi)
    end

    def test_build_type_class_of
      type = Type.class_of(Type.simple("String"))
      assert_equal("T.class_of(String)", type.to_rbi)
    end

    def test_build_type_self_type
      type = Type.self_type
      assert_equal("T.self_type", type.to_rbi)
    end

    def test_build_type_attached_class
      type = Type.attached_class
      assert_equal("T.attached_class", type.to_rbi)
    end

    def test_build_type_untyped
      type = Type.untyped
      assert_equal("T.untyped", type.to_rbi)
    end
  end
end
