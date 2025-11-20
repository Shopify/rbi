# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class TypeTest < Minitest::Test
    def test_build_type_simple_raises_if_incorrect_name
      Type.simple("String")
      Type.simple("::String")
      Type.simple("String::String")
      Type.simple("S1_1::S1_1")

      exception = assert_raises(NameError) do
        Type.simple("T.nilable(String)")
      end

      assert_equal("Invalid type name: `T.nilable(String)`", exception.message.lines.first.strip)

      exception = assert_raises(NameError) do
        Type.simple("String[Integer]")
      end

      assert_equal("Invalid type name: `String[Integer]`", exception.message.lines.first.strip)

      exception = assert_raises(NameError) do
        Type.simple("<< String")
      end

      assert_equal("Invalid type name: `<< String`", exception.message.lines.first.strip)
    end

    def test_build_type_string
      type = Type.simple("String")
      refute_predicate(type, :nilable?)
      assert_equal("String", type.to_rbi)
    end

    def test_build_type_anything
      type = Type.anything
      assert_equal("::T.anything", type.to_rbi)
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
      assert_equal("::T.nilable(String)", type.to_rbi)
    end

    def test_build_type_nilable_of_untyped
      type = Type.nilable(Type.untyped)
      assert_instance_of(Type::Untyped, type)
      assert_equal("::T.untyped", type.to_rbi)
    end

    def test_build_type_nilable_of_nilable
      type = Type.nilable(Type.nilable(Type.simple("String")))
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(String)", type.to_rbi)
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
      assert_equal("::T.all(String, Integer)", type.to_rbi)
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
      assert_equal("::T.all(String, Integer, Numeric)", type.to_rbi)
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
      assert_equal("::T.any(String, Integer)", type.to_rbi)

      type = Type.any(
        Type.simple("String"),
        Type.simple("String"),
        Type.simple("Integer"),
        Type.simple("Integer"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("::T.any(String, Integer)", type.to_rbi)
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
      assert_equal("::T.any(String, Integer, Symbol)", type.to_rbi)
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
      assert_equal("::T.any(String, Integer, Numeric, Symbol)", type.to_rbi)
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
      assert_equal("::T.nilable(String)", type.to_rbi)
    end

    def test_build_type_any_of_nilclass
      type = Type.any(
        Type.simple("String"),
        Type.simple("NilClass"),
      )
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(String)", type.to_rbi)
    end

    def test_build_type_any_of_nilable
      type = Type.any(
        Type.simple("String"),
        Type.nilable(Type.simple("Integer")),
      )
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(::T.any(String, Integer))", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass
      type = Type.any(
        Type.simple("TrueClass"),
        Type.simple("String"),
        Type.simple("FalseClass"),
      )
      assert_equal("::T.any(String, T::Boolean)", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass_and_nilclass
      type = Type.any(
        Type.simple("TrueClass"),
        Type.simple("NilClass"),
        Type.simple("FalseClass"),
      )
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(T::Boolean)", type.to_rbi)
    end

    def test_build_type_any_of_trueclass_and_falseclass_with_nilable
      type = Type.any(
        Type.simple("TrueClass"),
        Type.nilable(Type.simple("FalseClass")),
      )
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(T::Boolean)", type.to_rbi)
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
      assert_equal("{ foo: String, bar: Integer }", type.to_rbi)

      type = Type.shape(
        foo: Type.simple("String"),
        "bar": Type.simple("String"),
        "baz" => Type.simple("String"),
        :qux => Type.simple("String"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("{ foo: String, bar: String, baz: String, qux: String }", type.to_rbi)

      type = Type.shape(
        "\"foo\"": Type.simple("String"),
        "\"bar\"" => Type.simple("String"),
        :"\"baz\"" => Type.simple("String"),
      )
      refute_predicate(type, :nilable?)
      assert_equal("{ \"foo\": String, \"bar\": String, \"baz\": String }", type.to_rbi)
    end

    def test_build_type_void_proc
      type = Type.proc
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.void", type.to_rbi)
    end

    def test_build_type_void_proc_with_explicit_void_return_type
      type = Type.proc.void
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.void", type.to_rbi)
    end

    def test_build_type_void_proc_with_explicit_returns_with_void
      type = Type.proc.returns(Type.void)
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.void", type.to_rbi)
    end

    def test_build_type_void_proc_with_multiple_returns_specified
      type = Type.proc.returns(Type.simple("Integer")).void
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.void", type.to_rbi)
    end

    def test_build_type_void_nilable_proc
      type = Type.proc.nilable
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(::T.proc.void)", type.to_rbi)
    end

    def test_build_type_void_proc_with_params
      type = Type.proc.params(foo: Type.simple("String"), bar: Type.simple("Integer"))
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.params(foo: String, bar: Integer).void", type.to_rbi)
    end

    def test_build_type_void_nilable_proc_with_params
      type = Type.proc.params(foo: Type.simple("String"), bar: Type.simple("Integer")).nilable
      assert_predicate(type, :nilable?)
      assert_equal("::T.nilable(::T.proc.params(foo: String, bar: Integer).void)", type.to_rbi)
    end

    def test_build_type_symbol_returning_proc_with_params
      type = Type.proc.params(foo: Type.simple("String"), bar: Type.simple("Integer")).returns(Type.simple("Symbol"))
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.params(foo: String, bar: Integer).returns(Symbol)", type.to_rbi)
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
      assert_equal("::T.proc.bind(::T.class_of(Base)).params(foo: String, bar: Integer).returns(Symbol)", type.to_rbi)
    end

    def test_build_type_void_proc_with_bind
      type = Type.proc
        .bind(Type.class_of(Type.simple("Base")))
      refute_predicate(type, :nilable?)
      assert_equal("::T.proc.bind(::T.class_of(Base)).void", type.to_rbi)
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

    def test_build_type_parameter
      type = Type.type_parameter(:U)
      assert_equal("::T.type_parameter(:U)", type.to_rbi)

      type = Type.type_parameter(:" !")
      assert_equal("::T.type_parameter(:\" !\")", type.to_rbi)
    end

    def test_build_type_alias
      type = Type.type_alias("MyCustomType", Type.simple("String"))
      refute_predicate(type, :nilable?)
      assert_equal("MyCustomType = ::T.type_alias { String }", type.to_rbi)

      type = Type.type_alias("UserType", Type.generic("::T::Array", Type.simple("String")))
      refute_predicate(type, :nilable?)
      assert_equal("UserType = ::T.type_alias { ::T::Array[String] }", type.to_rbi)

      type = Type.type_alias("ComplexType", Type.any(Type.simple("String"), Type.simple("Integer")))
      refute_predicate(type, :nilable?)
      assert_equal("ComplexType = ::T.type_alias { ::T.any(String, Integer) }", type.to_rbi)
    end

    def test_build_type_alias_with_nilable_type
      type = Type.type_alias("OptionalType", Type.nilable(Type.simple("String")))
      refute_predicate(type, :nilable?)
      assert_equal("OptionalType = ::T.type_alias { ::T.nilable(String) }", type.to_rbi)
    end

    def test_build_type_alias_with_composite_types
      type = Type.type_alias("IntersectionType", Type.all(Type.simple("String"), Type.simple("Integer")))
      refute_predicate(type, :nilable?)
      assert_equal("IntersectionType = ::T.type_alias { ::T.all(String, Integer) }", type.to_rbi)

      type = Type.type_alias("UnionType", Type.any(Type.simple("String"), Type.simple("Integer")))
      refute_predicate(type, :nilable?)
      assert_equal("UnionType = ::T.type_alias { ::T.any(String, Integer) }", type.to_rbi)
    end

    def test_build_type_alias_with_proc_type
      proc_type = Type.proc.params(foo: Type.simple("String")).returns(Type.simple("Integer"))
      type = Type.type_alias("ProcType", proc_type)
      refute_predicate(type, :nilable?)
      assert_equal("ProcType = ::T.type_alias { ::T.proc.params(foo: String).returns(Integer) }", type.to_rbi)
    end

    def test_build_type_alias_with_shape_type
      shape_type = Type.shape(foo: Type.simple("String"), bar: Type.simple("Integer"))
      type = Type.type_alias("ShapeType", shape_type)
      refute_predicate(type, :nilable?)
      assert_equal("ShapeType = ::T.type_alias { { foo: String, bar: Integer } }", type.to_rbi)
    end

    def test_build_type_alias_with_tuple_type
      tuple_type = Type.tuple(Type.simple("String"), Type.simple("Integer"))
      type = Type.type_alias("TupleType", tuple_type)
      refute_predicate(type, :nilable?)
      assert_equal("TupleType = ::T.type_alias { [String, Integer] }", type.to_rbi)
    end

    def test_build_type_alias_with_class_of_type
      class_of_type = Type.class_of(Type.simple("String"))
      type = Type.type_alias("ClassOfType", class_of_type)
      refute_predicate(type, :nilable?)
      assert_equal("ClassOfType = ::T.type_alias { ::T.class_of(String) }", type.to_rbi)
    end

    def test_build_type_alias_with_t_class_type
      t_class_type = Type.t_class(Type.simple("String"))
      type = Type.type_alias("TClassType", t_class_type)
      refute_predicate(type, :nilable?)
      assert_equal("TClassType = ::T.type_alias { T::Class[String] }", type.to_rbi)
    end

    def test_build_type_alias_with_boolean_type
      boolean_type = Type.boolean
      type = Type.type_alias("BooleanType", boolean_type)
      refute_predicate(type, :nilable?)
      assert_equal("BooleanType = ::T.type_alias { T::Boolean }", type.to_rbi)
    end

    def test_build_type_alias_with_literal_types
      anything_type = Type.anything
      type = Type.type_alias("AnythingType", anything_type)
      refute_predicate(type, :nilable?)
      assert_equal("AnythingType = ::T.type_alias { ::T.anything }", type.to_rbi)

      untyped_type = Type.untyped
      type = Type.type_alias("UntypedType", untyped_type)
      refute_predicate(type, :nilable?)
      assert_equal("UntypedType = ::T.type_alias { ::T.untyped }", type.to_rbi)
    end

    def test_build_type_class_of
      type = Type.class_of(Type.simple("String"))
      assert_equal("::T.class_of(String)", type.to_rbi)
    end

    def test_build_type_class_of_generic
      type = Type.class_of(Type.simple("String"), Type.simple("Integer"))
      assert_equal("::T.class_of(String)[Integer]", type.to_rbi)
    end

    def test_buid_type_t_class
      type = Type.t_class(Type.simple("String"))
      assert_equal("T::Class[String]", type.to_rbi)
    end

    def test_buid_type_t_module
      type = Type.t_module(Type.simple("String"))
      assert_equal("T::Module[String]", type.to_rbi)
    end

    def test_build_type_self_type
      type = Type.self_type
      assert_equal("::T.self_type", type.to_rbi)
    end

    def test_build_type_attached_class
      type = Type.attached_class
      assert_equal("::T.attached_class", type.to_rbi)
    end

    def test_build_type_untyped
      type = Type.untyped
      assert_equal("::T.untyped", type.to_rbi)
    end

    def test_buid_type_noreturn
      type = Type.noreturn
      assert_equal("::T.noreturn", type.to_rbi)
    end

    def test_type_alias_normalize_and_simplify
      # Test that normalize and simplify return self for TypeAlias
      type = Type.type_alias("MyType", Type.simple("String"))

      normalized = type.normalize
      assert_instance_of(Type::TypeAlias, normalized)
      assert_equal("MyType = ::T.type_alias { String }", normalized.to_rbi)

      simplified = type.simplify
      assert_instance_of(Type::TypeAlias, simplified)
      assert_equal("MyType = ::T.type_alias { String }", simplified.to_rbi)

      # Test with complex types
      simplified_type_alias = Type.type_alias("ComplexType", Type.nilable(Type.simple("String")))

      normalized_complex = simplified_type_alias.normalize
      assert_instance_of(Type::TypeAlias, normalized_complex)
      assert_equal("ComplexType = ::T.type_alias { ::T.any(NilClass, String) }", normalized_complex.to_rbi)

      normalized_type_alias = Type.type_alias("ComplexType", Type.any(Type.simple("String"), Type.simple("NilClass")))

      simplified_complex = normalized_type_alias.simplify
      assert_instance_of(Type::TypeAlias, simplified_complex)
      assert_equal("ComplexType = ::T.type_alias { ::T.nilable(String) }", simplified_complex.to_rbi)
    end

    def test_types_comparison
      type1 = Type.simple("String")
      type2 = Type.simple("String")
      assert_equal(type1, type2)

      type3 = Type.simple("Integer")
      refute_equal(type1, type3)

      type4 = Type.nilable(Type.simple("String"))
      refute_equal(type1, type4)

      type5 = Type.nilable(Type.simple("String"))
      assert_equal(type4, type5)

      type6 = Type.generic("Foo", Type.simple("String"))
      type7 = Type.generic("Foo", Type.simple("String"))
      assert_equal(type6, type7)

      type8 = Type.generic("Foo", Type.simple("Integer"))
      refute_equal(type6, type8)

      type9 = Type.generic("Bar", Type.simple("String"))
      refute_equal(type6, type9)

      type10 = Type.any(Type.simple("String"), Type.simple("NilClass"))
      assert_equal(type4, type10)

      type11 = Type.any(Type.simple("String"), Type.simple("NilClass"))
      assert_equal(type10, type11)

      type12 = Type.any(Type.simple("String"), Type.simple("Integer"))
      refute_equal(type10, type12)

      type13 = Type.any(Type.simple("Integer"), Type.simple("String"))
      assert_equal(type12, type13)

      type15 = Type.untyped
      refute_equal(type1, type15)

      type16 = Type.boolean
      type17 = Type.any(Type.simple("TrueClass"), Type.simple("FalseClass"))
      assert_equal(type16, type17)

      type18 = Type.nilable(Type.untyped)
      assert_equal(type15, type18)

      type19 = Type.any(Type.simple("String"), Type.simple("String"))
      assert_equal(type19, type2)

      type20 = Type.all(Type.simple("String"), Type.simple("Integer"))
      type21 = Type.all(Type.simple("Integer"), Type.simple("String"))
      assert_equal(type20, type21)

      type22 = Type.shape(foo: Type.simple("String"), bar: Type.simple("Integer"))
      type23 = Type.shape(bar: Type.simple("Integer"), foo: Type.simple("String"))
      assert_equal(type22, type23)

      type24 = Type.shape(foo: Type.simple("Integer"), bar: Type.simple("String"))
      refute_equal(type22, type24)

      type25 = Type.tuple(Type.simple("String"), Type.simple("Integer"))
      type26 = Type.tuple(Type.simple("String"), Type.simple("Integer"))
      assert_equal(type25, type26)

      type27 = Type.tuple(Type.simple("Integer"), Type.simple("String"))
      refute_equal(type25, type27)

      # TypeAlias equality tests
      type28 = Type.type_alias("MyType", Type.simple("String"))
      type29 = Type.type_alias("MyType", Type.simple("String"))
      assert_equal(type28, type29)

      type30 = Type.type_alias("DifferentName", Type.simple("String"))
      refute_equal(type28, type30)

      type31 = Type.type_alias("MyType", Type.simple("Integer"))
      refute_equal(type28, type31)

      type32 = Type.type_alias("MyType", Type.nilable(Type.simple("String")))
      refute_equal(type28, type32)

      # TypeAlias with complex types
      type33 = Type.type_alias("ComplexType", Type.any(Type.simple("String"), Type.simple("Integer")))
      type34 = Type.type_alias("ComplexType", Type.any(Type.simple("String"), Type.simple("Integer")))
      assert_equal(type33, type34)

      type35 = Type.type_alias("ComplexType", Type.any(Type.simple("Integer"), Type.simple("String")))
      assert_equal(type33, type35)

      type36 = Type.type_alias("ComplexType", Type.any(Type.simple("String"), Type.simple("Symbol")))
      refute_equal(type33, type36)
    end
  end
end
