# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FlattenScopesTest < Minitest::Test
    def test_flatten_scopes
      rbi = RBI::Parser.parse_string(<<~RBI)
        class A
          module B
            class C; end
          end
        end
      RBI

      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        class ::A; end
        module ::A::B; end
        class ::A::B::C; end
      RBI
    end

    def test_flatten_scopes_and_keep_scopes_content
      rbi = RBI::Parser.parse_string(<<~RBI)
        class A
          module B
            class C
              def m3; end
            end
            def m2; end
          end
          def m1; end
        end
      RBI

      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        class ::A
          def m1; end
        end

        module ::A::B
          def m2; end
        end

        class ::A::B::C
          def m3; end
        end
      RBI
    end

    def test_flatten_scopes_and_keep_toplevel_content
      rbi = RBI::Parser.parse_string(<<~RBI)
        class A
          module B
            class C
              def m1; end
            end
          end
        end

        def m2; end
        attr_reader :a
        include Foo
        CST = 42
      RBI

      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        class ::A; end
        module ::A::B; end

        class ::A::B::C
          def m1; end
        end

        def m2; end
        attr_reader :a
        include Foo
        CST = 42
      RBI
    end

    def test_flatten_scopes_and_keep_toplevel_sclasses
      rbi = RBI::Parser.parse_string(<<~RBI)
        class A
          class << self
            def m1; end
          end
        end

        class << self
          def m2; end
        end
      RBI

      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        class ::A
          class << self
            def m1; end
          end
        end

        class << self
          def m2; end
        end
      RBI
    end

    def test_flatten_scopes_works_with_groups
      rbi = RBI::Parser.parse_string(<<~RBI)
        class A

          module B
            def m; end
          end
        end

        class << self
          def m; end
        end

        CST = 42
      RBI

      rbi.group_nodes!
      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        class ::A; end

        module ::A::B
          def m; end
        end

        class << self
          def m; end
        end

        CST = 42
      RBI
    end

    def test_flatten_scopes_works_with_visibility_groups
      rbi = RBI::Parser.parse_string(<<~RBI)
        class A
          private def m1; end
        end

        private def m2; end
      RBI

      rbi.nest_non_public_methods!
      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        class ::A
          private

          def m1; end
        end

        private

        def m2; end
      RBI
    end
  end
end
