# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class IndexTest < Minitest::Test
    extend T::Sig

    include TestHelper

    def test_index_empty
      tree = parse("")
      index = Index.new
      index.visit(tree)
      assert(index.empty?)
    end

    def test_index_scopes
      rb = <<~RB
        module A
          module B
            class C; end
            class ::D; end
          end
        end

        module A; end
        module B; end
        module C; end
      RB

      index = parse_and_index(rb)
      assert_equal(<<~INDEX, index)
        ::A: A, A
        ::A::B: B
        ::A::B::C: C
        ::B: B
        ::C: C
        ::D: ::D
      INDEX
    end

    def test_index_methods
      rb = <<~RB
        module A
          def foo; end
          module B
            def bar(a, b); end
          end
        end

        module A
          def foo; end
          def self.foo; end
          def bar; end
        end

        def foo; end
        def self.foo; end
      RB

      index = parse_and_index(rb)
      assert_equal(<<~INDEX, index)
        #foo: foo
        ::A: A, A
        ::A#bar: bar
        ::A#foo: foo, foo
        ::A::B: B
        ::A::B#bar: bar
        ::A::foo: foo
        ::foo: foo
      INDEX
    end

    def test_index_consts
      rb = <<~RB
        A = nil
        module B
          C = nil
          ::D = nil
        end
      RB

      index = parse_and_index(rb)
      assert_equal(<<~INDEX, index)
        ::A: A
        ::B: B
        ::B::C: C
        ::D: ::D
      INDEX
    end

    private

    sig { params(rb: String).returns(String) }
    def parse_and_index(rb)
      tree = parse(rb)
      index = Index.new
      index.visit(tree)

      out = StringIO.new
      index.print_index(out: out)
      out.string
    end
  end
end