# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class AddRootPrefixTest < Minitest::Test
    def test_add_root_prefix_to_toplevel_consts
      rbi = RBI::Parser.parse_string(<<~RBI)
        module M; end
        class C; end
        CST = 42
      RBI

      rbi.add_root_prefix!

      assert_equal(<<~RBI, rbi.string)
        module ::M; end
        class ::C; end
        ::CST = 42
      RBI
    end

    def test_do_not_add_root_prefix_to_nested_consts
      rbi = RBI::Parser.parse_string(<<~RBI)
        module M
          module M1
            module M2; end
          end
          CST1 = 42
        end

        class C
          class C1
            class C2; end
          end
          CST2 = 42
        end
      RBI

      rbi.add_root_prefix!

      assert_equal(<<~RBI, rbi.string)
        module ::M
          module M1
            module M2; end
          end

          CST1 = 42
        end

        class ::C
          class C1
            class C2; end
          end

          CST2 = 42
        end
      RBI
    end

    def test_no_not_add_root_prefix_to_already_prefixed_consts
      rbi = RBI::Parser.parse_string(<<~RBI)
        module ::M; end
        class ::C; end
        ::CST = 42
      RBI

      rbi.add_root_prefix!

      assert_equal(<<~RBI, rbi.string)
        module ::M; end
        class ::C; end
        ::CST = 42
      RBI
    end
  end
end
