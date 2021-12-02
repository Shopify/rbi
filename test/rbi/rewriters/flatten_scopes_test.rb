# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FlattenScopesTest < Minitest::Test
    def test_flatten_scopes_with_empty_scopes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          class B
            class C
              module D; end
            end
          end
        end

        module E; end
      RBI

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
        module A; end
        module E; end
        class A::B; end
        class A::B::C; end
        module A::B::C::D; end
      RBI
    end

    def test_flatten_scopes_with_nonempty_scopes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          A1 = 42

          class B
            class C
              C1 = 42

              module D; end
            end
          end
        end

        module E
          E1 = 42
        end
      RBI

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
        module A
          A1 = 42
        end

        module E
          E1 = 42
        end

        class A::B; end

        class A::B::C
          C1 = 42
        end

        module A::B::C::D; end
      RBI
    end

    def test_flatten_scopes_with_singleton_classes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          class B
            class C
              module D; end

              class << self
                def m1; end
              end
            end
          end
        end

        module E; end
      RBI

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
        module A; end
        module E; end
        class A::B; end

        class A::B::C
          class << self
            def m1; end
          end
        end

        module A::B::C::D; end
      RBI
    end

    def test_flatten_scopes_with_t_struct
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          class B < T::Struct
            const :foo, String

            class C
              module D; end
            end
          end
        end

        module E; end
      RBI

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
        module A; end
        module E; end

        class A::B < T::Struct
          const :foo, String
        end

        class A::B::C; end
        module A::B::C::D; end
      RBI
    end

    def test_flatten_scopes_with_t_enum
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          class B
            class C
              class D < T::Enum
                enums do
                  Foo = new
                  Bar = new
                end
              end
            end
          end
        end

        module E; end
      RBI

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
        module A; end
        module E; end
        class A::B; end
        class A::B::C; end

        class A::B::C::D < T::Enum
          enums do
            Foo = new
            Bar = new
          end
        end
      RBI
    end

    def test_flatten_duplicated_scopes
      rbi = RBI::Parser.parse_string(<<~RBI)
        module A
          class B; end
        end

        module A
          class C; end
        end

        module A
          class D; end
        end
      RBI

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
        module A; end
        module A; end
        module A; end
        class A::B; end
        class A::C; end
        class A::D; end
      RBI
    end

    def test_flatten_nested_trees
      rbi = Tree.new do |tree1|
        tree1 << Class.new("Foo") do |cls1|
          cls1 << Tree.new do |tree2|
            tree2 << Class.new("Bar") do |cls2|
              cls2 << Method.new("bar")
            end
          end
        end
      end

      rbi.flatten_scopes!

      assert_equal(<<~RBI, rbi.string)
      RBI
    end
  end
end
