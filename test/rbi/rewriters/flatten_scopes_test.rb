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
              def m2; end
            end
          end
        end

        def m1; end
      RBI

      rbi = rbi.flatten_scopes

      assert_equal(<<~RBI, rbi.string)
        def m1; end

        class ::A; end
        module ::A::B; end

        class ::A::B::C
          def m2; end
        end
      RBI
    end
  end
end
