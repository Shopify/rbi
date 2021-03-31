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
  end
end