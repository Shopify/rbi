# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class ParserTest < Minitest::Test
    include TestHelper

    def test_parse_empty_string_returns_empty_tree
      tree = parse("")
      assert(tree.empty?)
    end

    # Comments

    def test_parse_magic_comments
      rb = <<~RB
        # typed: true
        # frozen_string_literal: true
        # A real comment
        module A; end
      RB
      assert_print_same(rb)
    end

    def test_parse_discard_comments_from_empty_file
      rb = <<~RB
        # Comment line 1
        # Comment line 2
        # Comment line 3
      RB
      assert_print_equal("", rb)
    end

    def test_parse_multiline_comments
      rb = <<~RB
        # typed: true
        # Comment line 1
        # Comment line 2
        # Comment line 3
        module M; end
      RB
      assert_print_same(rb)
    end

    def test_parse_header_comments
      rb = <<~RB
        # A comment
        module A
          # B comment
          class B
            # c comment
            def c; end
            # d comment
            attr_reader
            # E comment
            E = _
          end
        end
      RB
      assert_print_same(rb)
    end

    def test_parse_move_trailing_comments
      rb = <<~RB
        # A comment 1
        # A comment 2
        module A
          # B comment
          class B; end
          # A comment 3
        end
      RB
      assert_print_equal(<<~EXP, rb)
        # A comment 1
        # A comment 2
        # A comment 3
        module A
          # B comment
          class B; end
        end
      EXP
    end

    def test_parse_discard_orphan_comments
      rb = <<~RB
        module A; end
        # Orphan comment
      RB
      assert_print_equal(<<~EXP, rb)
        module A; end
      EXP
    end

    # Scopes

    def test_parse_nesting
      rb = <<~RB
        module M
          module M1
            module M11
              module M111; end
              class M122; end
            end
            module M12; end
            class M13
              module M131; end
            end
          end
          module M2; end
        end
      RB
      assert_print_same(rb)
    end

    def test_parse_modules
      rb = <<~RB
        module A; end
        module ::B; end
        module A::B::C; end
        module ::A::B; end
      RB
      assert_print_same(rb)
    end

    def test_parse_classes
      rb = <<~RB
        class A; end
        class ::B < A; end
        class A::B::C < A::B; end
        class ::A::B < ::A::B; end
        class << self; end
      RB
      assert_print_same(rb)
    end

    # Consts

    def test_parse_consts
      rb = <<~RB
        A = nil
        B = 42
        C = 3.14
        D = "foo"
        E = :s
        F = CONST
        G = T.nilable(Foo)
        H = Foo.new
        I = T::Array[String].new
        ::J = CONST
        C::C::C = C::C::C
        C::C = foo
        ::C::C = foo
      RB
      assert_print_equal(<<~EXP, rb)
        A = _
        B = _
        C = _
        D = _
        E = _
        F = _
        G = _
        H = _
        I = _
        ::J = _
        C::C::C = _
        C::C = _
        ::C::C = _
      EXP
    end

    # Defs

    def test_parse_methods
      rb = <<~RB
        def foo; end
        def foo(x, *y, z:); end
        def foo(p1, p2 = 42, *p3); end
        def foo(p1:, p2: "foo", **p3); end
        def self.foo(p1:, p2: 3.14, p3: nil); end
        def self.foo(p1: T.let("", String), p2: T::Array[String].new, p3: [1, 2, {}]); end
      RB
      assert_print_equal(<<~EXP, rb)
        def foo; end
        def foo(x, *y, z:); end
        def foo(p1, p2 = _, *p3); end
        def foo(p1:, p2: _, **p3); end
        def self.foo(p1:, p2: _, p3: _); end
        def self.foo(p1: _, p2: _, p3: _); end
      EXP
    end

    # Sends

    def test_parse_sends
      rb = <<~RB
        attr_accessor(:a, :b)
        attr_reader(:a)
        attr_writer(:a)
        extend(B)
        include(A)
        prepend(C)
        foo
      RB
      assert_print_same(rb)
    end

    # Loc

    def test_parse_locations
      rbi = <<~RBI
        class Foo
          def foo; end
          def foo; end
          def foo(a, b:); end
          def foo(a); end
          attr_reader :a
        end
        def foo; end
      RBI
      assert_equal(<<~EXP, print(rbi, opts: { show_locs: true }))
        # -:1:0-7:3
        class Foo
          def foo; end # -:2:2-2:14
          def foo; end # -:3:2-3:14
          def foo(a, b:); end # -:4:2-4:21
          def foo(a); end # -:5:2-5:17
          attr_reader(:a) # -:6:2-6:16
        end
        def foo; end # -:8:0-8:12
      EXP
    end
  end
end
