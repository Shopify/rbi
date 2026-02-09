# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module RBS
    class TypeTranslatorTest < Minitest::Test
      include TestHelper

      def test_translate_alias
        assert_equal(Type.simple("Foo"), translate("foo"))
        assert_equal(Type.simple("FooBar"), translate("fooBar"))
        assert_equal(Type.simple("FooBar"), translate("foo_bar"))
        assert_equal(Type.simple("FooBarBaz"), translate("foo_bar_baz"))
        assert_equal(Type.simple("FooBarBazQux"), translate("foo_barBazQux"))
        assert_equal(Type.any(Type.simple("Foo"), Type.simple("String")), translate("foo | String"))
        assert_equal(Type.all(Type.simple("Foo"), Type.simple("::String")), translate("foo & ::String"))
        assert_equal(Type.any(Type.simple("::Bar::Foo"), Type.simple("String")), translate("::Bar::foo | String"))
        assert_equal(Type.all(Type.simple("Bar::Foo"), Type.simple("::String")), translate("Bar::foo & ::String"))
      end

      def test_translate_bases_any
        assert_equal(Type.untyped, translate("untyped"))
      end

      def test_translate_bases_bool
        assert_equal(Type.boolean, translate("bool"))
      end

      def test_translate_bases_bottom
        assert_equal(Type.noreturn, translate("bot"))
      end

      def test_translate_bases_class
        assert_equal(Type.untyped, translate("class"))
      end

      def test_translate_bases_instance
        assert_equal(Type.attached_class, translate("instance"))
      end

      def test_translate_bases_nil
        assert_equal(Type.simple("NilClass"), translate("nil"))
      end

      def test_translate_bases_self
        assert_equal(Type.self_type, translate("self"))
      end

      def test_translate_bases_top
        assert_equal(Type.anything, translate("top"))
      end

      def test_translate_bases_void
        assert_equal(Type.void, translate("void"))
      end

      def test_translate_class_instance
        assert_equal(Type.simple("Foo"), translate("Foo"))
        assert_equal(Type.simple("Foo::Bar"), translate("Foo::Bar"))
        assert_equal(Type.simple("::Foo::Bar"), translate("::Foo::Bar"))
        assert_equal(Type.generic("Foo", Type.simple("Bar"), Type.simple("::Baz")), translate("Foo[Bar, ::Baz]"))
      end

      def test_translate_class_instance_generics_as_t_types
        assert_equal(Type.generic("::T::Array", Type.simple("Foo")), translate("Array[Foo]"))
        assert_equal(Type.generic("::T::Class", Type.simple("Foo")), translate("Class[Foo]"))
        assert_equal(Type.generic("::T::Enumerable", Type.simple("Foo")), translate("Enumerable[Foo]"))
        assert_equal(Type.generic("::T::Enumerator", Type.simple("Foo")), translate("Enumerator[Foo]"))
        assert_equal(Type.generic("::T::Enumerator::Chain", Type.simple("Foo")), translate("Enumerator::Chain[Foo]"))
        assert_equal(Type.generic("::T::Enumerator::Lazy", Type.simple("Foo")), translate("Enumerator::Lazy[Foo]"))
        assert_equal(Type.generic("::T::Hash", Type.simple("Foo"), Type.simple("Bar")), translate("Hash[Foo, Bar]"))
        assert_equal(Type.generic("::T::Module", Type.simple("Foo")), translate("Module[Foo]"))
        assert_equal(Type.generic("::T::Set", Type.simple("Foo")), translate("Set[Foo]"))
        assert_equal(Type.generic("::T::Range", Type.simple("Foo"), Type.simple("Bar")), translate("Range[Foo, Bar]"))

        assert_equal(Type.generic("::T::Array", Type.simple("Foo")), translate("::Array[Foo]"))
        assert_equal(Type.generic("::T::Class", Type.simple("Foo")), translate("::Class[Foo]"))
        assert_equal(Type.generic("::T::Enumerable", Type.simple("Foo")), translate("::Enumerable[Foo]"))
        assert_equal(Type.generic("::T::Enumerator", Type.simple("Foo")), translate("::Enumerator[Foo]"))
        assert_equal(Type.generic("::T::Enumerator::Chain", Type.simple("Foo")), translate("::Enumerator::Chain[Foo]"))
        assert_equal(Type.generic("::T::Enumerator::Lazy", Type.simple("Foo")), translate("::Enumerator::Lazy[Foo]"))
        assert_equal(Type.generic("::T::Hash", Type.simple("Foo"), Type.simple("Bar")), translate("::Hash[Foo, Bar]"))
        assert_equal(Type.generic("::T::Module", Type.simple("Foo")), translate("::Module[Foo]"))
        assert_equal(Type.generic("::T::Set", Type.simple("Foo")), translate("::Set[Foo]"))
        assert_equal(Type.generic("::T::Range", Type.simple("Foo"), Type.simple("Bar")), translate("::Range[Foo, Bar]"))
      end

      def test_translate_class_singleton
        assert_equal(Type.class_of(Type.simple("Foo")), translate("singleton(Foo)"))
        assert_equal(Type.class_of(Type.simple("Foo::Bar")), translate("singleton(Foo::Bar)"))
        assert_equal(Type.class_of(Type.simple("::Foo::Bar")), translate("singleton(::Foo::Bar)"))

        e = assert_raises(::RBS::ParsingError) do
          translate("singleton(Foo)[Bar]")
        end
        assert_equal("a.rbs:1:14...1:15: Syntax error: expected a token `pEOF`, token=`[` (pLBRACKET)", e.message)
      end

      def test_translate_interface
        assert_equal(Type.untyped, translate("_Foo"))
      end

      def test_translate_intersection
        assert_equal(Type.all(Type.simple("Foo"), Type.simple("Bar")), translate("Foo & Bar"))
      end

      def test_translate_literal
        assert_equal(Type.untyped, translate("1"))
        assert_equal(Type.untyped, translate("\"foo\""))
        assert_equal(Type.untyped, translate("true"))
        assert_equal(Type.untyped, translate("false"))
        assert_equal(Type.untyped, translate(":foo"))
      end

      def test_translate_optional
        assert_equal(Type.nilable(Type.simple("String")), translate("String?"))
      end

      def test_translate_proc
        assert_equal(
          Type.proc
            .bind(Type.simple("Foo"))
            .params(arg0: Type.simple("Integer"), arg1: Type.simple("String"))
            .returns(Type.simple("Integer")),
          translate("^ (Integer, String) [self: Foo] -> Integer"),
        )

        assert_equal(
          Type.proc
            .params(
              a: Type.simple("A"),
              b: Type.simple("B"),
              c: Type.simple("C"),
              d: Type.simple("D"),
              e: Type.simple("E"),
              f: Type.simple("F"),
            )
            .returns(Type.void),
          translate("^ (A a, B b, *C c, d: D, ?e: E, **F f) -> void"),
        )
      end

      def test_translate_record
        assert_equal(Type.shape(foo: Type.simple("String")), translate("{foo: String}"))
      end

      def test_translate_tuple
        assert_equal(Type.tuple([Type.simple("Foo"), Type.simple("Bar")]), translate("[Foo, Bar]"))
      end

      def test_translate_union
        assert_equal(Type.any(Type.simple("String"), Type.simple("Integer")), translate("String | Integer"))
      end

      def test_translate_untyped_function
        assert_equal(
          Type.proc.params(arg0: Type.untyped).returns(Type.untyped),
          translate("^ (?) -> untyped"),
        )
      end

      private

      #: (String) -> RBI::Type
      def translate(rbs_string)
        node = ::RBS::Parser.parse_type(rbs_string, require_eof: true)
        RBS::TypeTranslator.translate(node)
      end
    end
  end
end
