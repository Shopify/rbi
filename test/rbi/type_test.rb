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

    def test_build_non_nilable_of_simple_type
      type = Type.simple("String").non_nilable
      refute_predicate(type, :nilable?)
      assert_equal("String", type.to_rbi)
    end

    def test_build_non_nilable_of_nilable_type
      type = Type.simple("String").nilable.non_nilable
      refute_predicate(type, :nilable?)
      assert_equal("String", type.to_rbi)
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
          Type.simple("Integer"),
        ),
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
        Type.simple("Integer"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("T.any(String, Integer)", type.to_rbi)

      type = Type.any(
        Type.simple("String"),
        Type.simple("String"),
        Type.simple("Integer"),
        Type.simple("Integer"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("T.any(String, Integer)", type.to_rbi)
    end

    def test_build_type_any_of_any
      type = Type.any(
        Type.any(
          Type.simple("String"),
          Type.simple("Integer"),
        ),
        Type.any(
          Type.simple("String"),
          Type.simple("Symbol"),
        ),
      )

      assert_instance_of(Type::Any, type)
      assert_equal("T.any(String, Integer, Symbol)", type.to_rbi)
    end

    def test_build_type_any_of_any_of_any
      type = Type.any(
        Type.any(
          Type.simple("String"),
          Type.simple("Integer"),
        ),
        Type.any(
          Type.simple("Numeric"),
          Type.any(
            Type.simple("String"),
            Type.simple("Symbol"),
          ),
        ),
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
        Type.simple("NilClass"),
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

    def test_build_type_any_of_just_nilclass
      type = Type.any(
        Type.simple("NilClass"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("NilClass", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass
      type = Type.any(
        Type.simple("TrueClass"),
        Type.simple("String"),
        Type.simple("FalseClass"),
      )
      assert_equal("T.any(String, T::Boolean)", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass_and_nilclass
      type = Type.any(
        Type.simple("TrueClass"),
        Type.simple("NilClass"),
        Type.simple("FalseClass"),
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T::Boolean)", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass_with_nilable
      type = Type.any(
        Type.simple("TrueClass"),
        Type.nilable(Type.simple("FalseClass")),
      )
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T::Boolean)", type.to_rbi)
    end

    def test_build_type_tuple
      type = Type.tuple(
        Type.simple("String"),
        Type.simple("Integer"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("[String, Integer]", type.to_rbi)
    end

    def test_build_type_empty_tuple
      type = Type.tuple
      refute_predicate(type, :nilable?)
      assert_equal("[]", type.to_rbi)
    end

    def test_build_type_shape
      type = Type.shape(
        foo: Type.simple("String"),
        bar: Type.simple("Integer"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("{foo: String, bar: Integer}", type.to_rbi)
    end

    def test_build_type_void_proc
      type = Type.proc
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.void", type.to_rbi)
    end

    def test_build_type_void_proc_with_explicit_void_return_type
      type = Type.proc.void
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.void", type.to_rbi)
    end

    def test_build_type_void_proc_with_explicit_returns_with_void
      type = Type.proc.returns(Type.void)
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.void", type.to_rbi)
    end

    def test_build_type_void_proc_with_multiple_returns_specified
      type = Type.proc.returns(Type.simple("Integer")).void
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.void", type.to_rbi)
    end

    def test_build_type_void_nilable_proc
      type = Type.proc.nilable
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T.proc.void)", type.to_rbi)
    end

    def test_build_type_void_proc_with_params
      type = Type.proc.params(foo: Type.simple("String"), bar: Type.simple("Integer"))
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.params(foo: String, bar: Integer).void", type.to_rbi)
    end

    def test_build_type_void_nilable_proc_with_params
      type = Type.proc.params(foo: Type.simple("String"), bar: Type.simple("Integer")).nilable
      assert_predicate(type, :nilable?)
      assert_equal("T.nilable(T.proc.params(foo: String, bar: Integer).void)", type.to_rbi)
    end

    def test_build_type_symbol_returning_proc_with_params
      type = Type.proc.params(foo: Type.simple("String"), bar: Type.simple("Integer")).returns(Type.simple("Symbol"))
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.params(foo: String, bar: Integer).returns(Symbol)", type.to_rbi)
    end

    def test_build_type_symbol_returning_proc_with_params_and_bind
      type = Type.proc
        .params(
          foo: Type.simple("String"),
          bar: Type.simple("Integer"),
        )
        .returns(Type.simple("Symbol"))
        .bind(Type.class_of(Type.simple("Base")))
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.bind(T.class_of(Base)).params(foo: String, bar: Integer).returns(Symbol)", type.to_rbi)
    end

    def test_build_type_void_proc_with_bind
      type = Type.proc
        .bind(Type.class_of(Type.simple("Base")))
      refute_predicate(type, :nilable?)
      assert_equal("T.proc.bind(T.class_of(Base)).void", type.to_rbi)
    end

    def test_build_type_empty_shape
      type = Type.shape
      refute_predicate(type, :nilable?)
      assert_equal("{}", type.to_rbi)
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
