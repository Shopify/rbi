# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module RBS
    class MethodTypeTranslatorTest < Minitest::Test
      include TestHelper

      def test_translate_void
        sig = translate(
          "() -> void",
          Method.new("foo"),
        )

        assert_empty(sig.params)
        assert_equal(Type.void, sig.return_type)
      end

      def test_translate_return_type
        sig = translate(
          "() -> Foo",
          Method.new("foo"),
        )

        assert_equal(Type.simple("Foo"), sig.return_type)

        sig = translate(
          "() -> ::Foo",
          Method.new("foo"),
        )

        assert_equal(Type.simple("::Foo"), sig.return_type)

        sig = translate(
          "() -> Foo::Bar",
          Method.new("foo"),
        )

        assert_equal(Type.simple("Foo::Bar"), sig.return_type)
      end

      def test_translate_named_positionals
        sig = translate(
          "(Integer x, String y) -> Integer",
          Method.new("foo"),
        )

        assert_equal(
          [
            SigParam.new("x", Type.simple("Integer")),
            SigParam.new("y", Type.simple("String")),
          ],
          sig.params,
        )
      end

      def test_translate_named_positionals_raises_if_name_is_missing
        assert_raises(RBI::RBS::MethodTypeTranslator::Error) do
          translate(
            "(Integer, String) -> Integer",
            Method.new("foo", params: [
              ReqParam.new("x"),
            ]),
          )
        end
      end

      def test_translate_named_positionals_get_names_from_method
        sig = translate(
          "(Integer, String) -> Integer",
          Method.new("foo", params: [
            ReqParam.new("x"),
            OptParam.new("y", "42"),
          ]),
        )

        assert_equal(
          [
            SigParam.new("x", Type.simple("Integer")),
            SigParam.new("y", Type.simple("String")),
          ],
          sig.params,
        )
      end

      def test_translate_params
        sig = translate(
          "(A a, B b, *C, d: D, ?e: E, **F) -> Integer",
          Method.new("foo", params: [
            ReqParam.new("a"),
            OptParam.new("b", "42"),
            RestParam.new("c"),
            KwParam.new("d"),
            KwOptParam.new("e", "43"),
            KwRestParam.new("f"),
          ]),
        )

        assert_equal(
          [
            SigParam.new("a", Type.simple("A")),
            SigParam.new("b", Type.simple("B")),
            SigParam.new("c", Type.simple("C")),
            SigParam.new("d", Type.simple("D")),
            SigParam.new("e", Type.simple("E")),
            SigParam.new("f", Type.simple("F")),
          ],
          sig.params,
        )
      end

      def test_translate_block_param
        sig = translate(
          "() { (Integer) [self: Foo] -> String } -> void",
          Method.new("foo", params: [
            BlockParam.new("block"),
          ]),
        )

        assert_equal(
          [
            SigParam.new(
              "block",
              Type.proc
                .params(arg0: Type.simple("Integer"))
                .returns(Type.simple("String"))
                .bind(Type.simple("Foo")),
            ),
          ],
          sig.params,
        )
      end

      def test_translate_block_param_optional
        sig = translate(
          "() ?{ (Integer) [self: Foo] -> String } -> void",
          Method.new("foo", params: [
            BlockParam.new("block"),
          ]),
        )

        assert_equal(
          [
            SigParam.new(
              "block",
              Type.nilable(
                Type.proc
                  .params(arg0: Type.simple("Integer"))
                  .returns(Type.simple("String"))
                  .bind(Type.simple("Foo")),
              ),
            ),
          ],
          sig.params,
        )
      end

      def test_translate_raises_if_block_param_is_missing
        assert_raises(RBI::RBS::MethodTypeTranslator::Error) do
          translate(
            "() { (Integer) -> String } -> void",
            Method.new("foo"),
          )
        end
      end

      def test_translate_type_params
        sig = translate(
          "[T, U, V] (T, U, V) -> void",
          Method.new("foo", params: [
            ReqParam.new("t"),
            ReqParam.new("u"),
            ReqParam.new("v"),
          ]),
        )

        assert_equal(
          [
            SigParam.new("t", Type.type_parameter(:T)),
            SigParam.new("u", Type.type_parameter(:U)),
            SigParam.new("v", Type.type_parameter(:V)),
          ],
          sig.params,
        )
      end

      def test_translate_generic_singleton
        sig = translate(
          "-> singleton(Foo)[Bar]",
          Method.new("foo"),
        )

        assert_equal(Type.class_of(Type.simple("Foo"), Type.simple("Bar")), sig.return_type)
      end

      def test_erase_generic_types_replaces_method_type_parameters
        sig = translate(
          "[T, U] (Array[T], T?, T | Integer, [T, Integer], singleton(Foo)[T]) { (T) -> U } -> U?",
          Method.new("foo", params: [
            ReqParam.new("array"),
            ReqParam.new("value"),
            ReqParam.new("fallback"),
            ReqParam.new("pair"),
            ReqParam.new("klass"),
            BlockParam.new("block"),
          ]),
          erase_generic_types: true,
        )

        assert_empty(sig.type_params)
        assert_equal(
          [
            SigParam.new("array", Type.simple("Array")),
            SigParam.new("value", Type.nilable(Type.anything)),
            SigParam.new("fallback", Type.any(Type.anything, Type.simple("Integer"))),
            SigParam.new("pair", Type.tuple([Type.anything, Type.simple("Integer")])),
            SigParam.new("klass", Type.class_of(Type.simple("Foo"))),
            SigParam.new(
              "block",
              Type.proc
                .params(arg0: Type.anything)
                .returns(Type.anything),
            ),
          ],
          sig.params,
        )
        assert_equal(Type.nilable(Type.anything), sig.return_type)
      end

      private

      #: (String, Method, ?erase_generic_types: bool) -> RBI::Sig
      def translate(rbs_string, method, erase_generic_types: false)
        node = ::RBS::Parser.parse_method_type(rbs_string, require_eof: true)

        options = MethodTypeTranslator::Options.new(erase_generic_types:)

        translator = RBS::MethodTypeTranslator.new(method, options:)
        translator.visit(node)
        translator.result
      end
    end
  end
end
