# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class TranslateRBSSigsTest < Minitest::Test
    include TestHelper

    def test_does_nothing_if_no_rbs_comments
      rbi = <<~RBI
        class Foo
          attr_reader :a
          def bar; end
        end
      RBI

      assert_equal(rbi, rewrite(rbi))
    end

    def test_translate_method_sigs
      tree = rewrite(<<~RBI)
        #: -> void
        def foo; end

        class Foo
          #: (Integer? a, ?Integer b, *Integer c, d: Integer, ?e: Integer, **Integer) { (Integer) -> String } -> ::Foo
          def bar(a, b = 42, *c, d:, e: 43, **f, &g); end

          #: (Integer, ?Integer) -> Foo::Bar
          def self.baz(a, b = 42); end
        end
      RBI

      assert_equal(<<~RBI, tree)
        sig { void }
        def foo; end

        class Foo
          sig { params(a: ::T.nilable(Integer), b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: ::T.proc.params(arg0: Integer).returns(String)).returns(::Foo) }
          def bar(a, b = 42, *c, d:, e: 43, **f, &g); end

          sig { params(a: Integer, b: Integer).returns(Foo::Bar) }
          def self.baz(a, b = 42); end
        end
      RBI
    end

    def test_translate_attr_sigs
      tree = rewrite(<<~RBI)
        #: Integer
        attr_reader :a

        #: Integer
        attr_writer :b

        #: Integer
        attr_accessor :c, :d
      RBI

      assert_equal(<<~RBI, tree)
        sig { returns(Integer) }
        attr_reader :a

        sig { params(b: Integer).returns(Integer) }
        attr_writer :b

        sig { returns(Integer) }
        attr_accessor :c, :d
      RBI
    end

    def test_translate_multiline_sigs
      tree = rewrite(<<~RBI)
        #: Array[
        #|   Integer
        #| ]
        attr_reader :a

        #: (
        #|   Integer
        #| ) -> Integer
        def foo(a); end
      RBI

      assert_equal(<<~RBI, tree)
        sig { returns(::T::Array[Integer]) }
        attr_reader :a

        sig { params(a: Integer).returns(Integer) }
        def foo(a); end
      RBI
    end

    def test_translate_generic_singleton
      e = assert_raises(::RBS::ParsingError) do
        rewrite(<<~RBI)
          #: -> singleton(Foo)[Bar]
          def foo; end
        RBI
      end

      assert_equal("a.rbs:1:17...1:18: Syntax error: expected a token `pEOF`, token=`[` (pLBRACKET)", e.message)
    end

    private

    #: (String) -> String
    def rewrite(rbi)
      tree = parse_rbi(rbi)
      tree.translate_rbs_sigs!
      tree.string
    end
  end
end
