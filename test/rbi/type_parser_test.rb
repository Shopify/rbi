# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class TypeParserTest < Minitest::Test
    def test_parse_empty
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("")
      end
      assert_equal("Expected a type expression, got nothing", e.message)
    end

    def test_parse_multiple_type_expressions
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string(<<~RBI)
          void
          T.untyped
        RBI
      end
      assert_equal("Expected a single type expression, got `void\nT.untyped`", e.message)
    end

    def test_parse_wrong_bracket_expression
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string(<<~RBI)
          void[]
        RBI
      end
      assert_equal("Unexpected expression `void[]`", e.message)
    end

    def test_parse_wrong_call_expression
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string(<<~RBI)
          Foo.void
        RBI
      end
      assert_equal("Unexpected expression `Foo.void`", e.message)
    end

    def test_parse_wrong_t_method
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string(<<~RBI)
          T.invalid
        RBI
      end
      assert_equal("Unexpected expression `T.invalid`", e.message)
    end

    def test_parse_simple
      type = Type.parse_string("Foo")
      assert_equal("Foo", type.to_s)

      type = Type.parse_string("Foo::Bar")
      assert_equal("Foo::Bar", type.to_s)

      type = Type.parse_string("::Foo::Bar")
      assert_equal("::Foo::Bar", type.to_s)
    end

    def test_parse_boolean
      type = Type.parse_string("T::Boolean")
      assert_equal(Type.boolean, type)

      type = Type.parse_string("::T::Boolean")
      assert_equal(Type.boolean, type)
    end

    def test_parse_anything
      type = Type.parse_string("T.anything")
      assert_equal(Type.anything, type)

      type = Type.parse_string("::T.anything")
      assert_equal(Type.anything, type)
    end

    def test_parse_void
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("void(42)")
      end
      assert_equal("Expected no arguments, got 1", e.message)

      type = Type.parse_string("void")
      assert_equal(Type.void, type)
    end

    def test_parse_untyped
      type = Type.parse_string("T.untyped")
      assert_equal(Type.untyped, type)

      type = Type.parse_string("::T.untyped")
      assert_equal(Type.untyped, type)
    end

    def test_parse_self_type
      type = Type.parse_string("T.self_type")
      assert_equal(Type.self_type, type)

      type = Type.parse_string("::T.self_type")
      assert_equal(Type.self_type, type)
    end

    def test_parse_attached_class
      type = Type.parse_string("T.attached_class")
      assert_equal(Type.attached_class, type)

      type = Type.parse_string("::T.attached_class")
      assert_equal(Type.attached_class, type)
    end

    def test_parse_nilable
      type = Type.parse_string("T.nilable(Foo)")
      assert_equal(Type.nilable(Type.simple("Foo")), type)

      type = Type.parse_string("::T.nilable(Foo)")
      assert_equal(Type.nilable(Type.simple("Foo")), type)

      type = Type.parse_string("T.nilable(Foo::Bar)")
      assert_equal(Type.nilable(Type.simple("Foo::Bar")), type)

      type = Type.parse_string("T.nilable(::Foo::Bar)")
      assert_equal(Type.nilable(Type.simple("::Foo::Bar")), type)
    end

    def test_parse_class
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T::Class[]")
      end
      assert_equal("Expected exactly 1 argument, got 0", e.message)

      type = Type.parse_string("T::Class[Foo]")
      assert_equal(Type.t_class(Type.simple("Foo")), type)
    end

    def test_parse_module
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T::Module[]")
      end
      assert_equal("Expected exactly 1 argument, got 0", e.message)

      type = Type.parse_string("T::Module[Foo]")
      assert_equal(Type.t_module(Type.simple("Foo")), type)
    end

    def test_parse_class_of
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.class_of")
      end
      assert_equal("Expected exactly 1 argument, got 0", e.message)

      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.class_of(Foo, Bar)")
      end
      assert_equal("Expected exactly 1 argument, got 2", e.message)

      type = Type.parse_string("T.class_of(Foo)")
      assert_equal(Type.class_of(Type.simple("Foo")), type)

      type = Type.parse_string("T.class_of(Foo::Bar)")
      assert_equal(Type.class_of(Type.simple("Foo::Bar")), type)

      type = Type.parse_string("T.class_of(::Foo::Bar)")
      assert_equal(Type.class_of(Type.simple("::Foo::Bar")), type)

      type = Type.parse_string("T.class_of(Foo)[Bar]")
      assert_equal(Type.class_of(Type.simple("Foo"), Type.simple("Bar")), type)

      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.class_of(T.nilable(Foo))")
      end
      assert_equal("Expected a simple type, got `::T.nilable(Foo)`", e.message)

      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.class_of(Foo)[]")
      end
      assert_equal("Expected exactly 1 argument, got 0", e.message)
    end

    def test_parse_all
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.all(Foo)")
      end
      assert_equal("Expected at least 2 arguments, got 1", e.message)

      type = Type.parse_string("T.all(Foo, Bar)")
      assert_equal(
        Type.all(
          Type.simple("Foo"),
          Type.simple("Bar"),
        ),
        type,
      )

      type = Type.parse_string("T.all(Foo, ::Bar, ::Foo::Bar)")
      assert_equal(
        Type.all(
          Type.simple("Foo"),
          Type.simple("::Bar"),
          Type.simple("::Foo::Bar"),
        ),
        type,
      )

      type = Type.parse_string("::T.all(Foo, ::Bar, ::Foo::Bar)")
      assert_equal(
        Type.all(
          Type.simple("Foo"),
          Type.simple("::Bar"),
          Type.simple("::Foo::Bar"),
        ),
        type,
      )
    end

    def test_parse_any
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.any(Foo)")
      end
      assert_equal("Expected at least 2 arguments, got 1", e.message)

      type = Type.parse_string("T.any(Foo, Bar)")
      assert_equal(
        Type.any(
          Type.simple("Foo"),
          Type.simple("Bar"),
        ),
        type,
      )

      type = Type.parse_string("T.any(Foo, ::Bar, ::Foo::Bar)")
      assert_equal(
        Type.any(
          Type.simple("Foo"),
          Type.simple("::Bar"),
          Type.simple("::Foo::Bar"),
        ),
        type,
      )

      type = Type.parse_string("::T.any(Foo, ::Bar, ::Foo::Bar)")
      assert_equal(
        Type.any(
          Type.simple("Foo"),
          Type.simple("::Bar"),
          Type.simple("::Foo::Bar"),
        ),
        type,
      )
    end

    def test_parse_generic
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("Foo[]")
      end
      assert_equal("Expected at least 1 argument, got 0", e.message)

      type = Type.parse_string("Foo[Bar]")
      assert_equal(
        Type.generic(
          "Foo",
          Type.simple("Bar"),
        ),
        type,
      )

      type = Type.parse_string("::Foo::Bar[::Baz, ::Foo::Bar]")
      assert_equal(
        Type.generic(
          "::Foo::Bar",
          Type.simple("::Baz"),
          Type.simple("::Foo::Bar"),
        ),
        type,
      )
    end

    def test_parse_type_parameter
      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.type_parameter")
      end
      assert_equal("Expected exactly 1 argument, got 0", e.message)

      type = Type.parse_string("T.type_parameter(:U)")
      assert_equal(Type.type_parameter(:U), type)

      type = Type.parse_string("::T.type_parameter(:U)")
      assert_equal(Type.type_parameter(:U), type)

      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("::T.type_parameter(Foo)")
      end
      assert_equal("Expected a symbol, got `Foo`", e.message)
    end

    def test_parse_tuple
      type = Type.parse_string("[Foo, ::Bar::Baz]")
      assert_equal(
        Type.tuple(
          Type.simple("Foo"),
          Type.simple("::Bar::Baz"),
        ),
        type,
      )
    end

    def test_parse_shape
      type = Type.parse_string("{:foo => Foo, bar: ::Bar, \"baz\" => Baz::Baz, :\"qux\" => ::Qux::Qux}")
      assert_equal(
        Type.shape(
          foo: Type.simple("Foo"),
          bar: Type.simple("::Bar"),
          "baz" => Type.simple("Baz::Baz"),
          qux: Type.simple("::Qux::Qux"),
        ),
        type,
      )
    end

    def test_parse_proc
      type = Type.parse_string("T.proc.void")
      assert_equal(Type.proc.void, type)

      type = Type.parse_string(<<~RBI)
        T
          .proc
          .void
      RBI
      assert_equal(Type.proc.void, type)

      type = Type.parse_string("T.proc.returns(Integer)")
      assert_equal(
        Type.proc.returns(Type.simple("Integer")),
        type,
      )

      type = Type.parse_string("T.proc.params(foo: Foo).returns(Baz).bind(Baz)")
      assert_equal(
        Type.proc
          .params(foo: Type.simple("Foo"))
          .returns(Type.simple("Baz"))
          .bind(Type.simple("Baz")),
        type,
      )

      e = assert_raises(RBI::Type::Error) do
        Type.parse_string("T.proc.foo")
      end
      assert_equal("Unexpected expression `T.proc.foo`", e.message)
    end

    def test_parse_complex_type
      type = Type.parse_string(<<~RBI)
        T.proc.params(
          foo: [{foo: Foo, bar: Bar}, T::Boolean],
          bar: T.nilable(T.class_of(Baz)),
          baz: T.all(T.any(Foo, Bar), T::Boolean)
        ).returns(
          Foo[Bar, T.nilable(Baz)]
        )
      RBI
      assert_equal(
        Type.proc.params(
          foo: Type.tuple(
            Type.shape(
              foo: Type.simple("Foo"),
              bar: Type.simple("Bar"),
            ),
            Type.boolean,
          ),
          bar: Type.nilable(Type.class_of(Type.simple("Baz"))),
          baz: Type.all(
            Type.any(
              Type.simple("Foo"),
              Type.simple("Bar"),
            ),
            Type.boolean,
          ),
        ).returns(
          Type.generic(
            "Foo",
            Type.simple("Bar"),
            Type.nilable(Type.simple("Baz")),
          ),
        ),
        type,
      )
    end

    def test_parse_parenthesis
      type = Type.parse_string("(Foo)")
      assert_equal(Type.simple("Foo"), type)

      type = Type.parse_string("((Foo))")
      assert_equal(Type.simple("Foo"), type)

      type = Type.parse_string("Foo[(((Foo)))]")
      assert_equal(Type.generic("Foo", Type.simple("Foo")), type)

      type = Type.parse_string("T.nilable((T.any((Foo), (Bar))))")
      assert_equal(Type.nilable(Type.any(Type.simple("Foo"), Type.simple("Bar"))), type)
    end

    def test_parse_type_alias
      type = Type.parse_string("MyType = T.type_alias { String }")
      assert_equal(Type.type_alias("MyType", Type.simple("String")), type)

      type = Type.parse_string("MyType = T.type_alias { T.any(String, Integer) }")
      assert_equal(Type.type_alias("MyType", Type.any(Type.simple("String"), Type.simple("Integer"))), type)

      type = Type.parse_string("MyType = T.type_alias { T.all(T.any(String, Integer), T::Boolean) }")
      assert_equal(
        Type.type_alias("MyType", Type.all(Type.any(Type.simple("String"), Type.simple("Integer")), Type.boolean)),
        type,
      )

      type = Type.parse_string("MyType = T.type_alias { T.proc.void }")
      assert_equal(Type.type_alias("MyType", Type.proc.void), type)

      type = Type.parse_string("MyType = T.type_alias { T.proc.params(foo: Foo).returns(Baz).bind(Baz) }")
      assert_equal(
        Type.type_alias(
          "MyType",
          Type.proc.params(foo: Type.simple("Foo")).returns(Type.simple("Baz")).bind(Type.simple("Baz")),
        ),
        type,
      )

      type = Type.parse_string("::Foo::MyType = T.type_alias { String }")
      assert_equal(Type.type_alias("::Foo::MyType", Type.simple("String")), type)

      type = Type.parse_string("::Foo::MyType = ::T.type_alias { T.any(String, Integer) }")
      assert_equal(Type.type_alias("::Foo::MyType", Type.any(Type.simple("String"), Type.simple("Integer"))), type)
    end

    def test_parse_keyword_hash
      type = Type.parse_string("T.proc.returns(:foo => Foo, bar: ::Bar, \"baz\" => Baz::Baz, :\"qux\" => ::Qux::Qux)")
      assert_equal(
        Type.proc.returns(
          Type.shape(
            foo: Type.simple("Foo"),
            bar: Type.simple("::Bar"),
            "baz" => Type.simple("Baz::Baz"),
            qux: Type.simple("::Qux::Qux"),
          ),
        ),
        type,
      )
    end
  end
end
