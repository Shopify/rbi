# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FlattenNamespacesTest < Minitest::Test
    include TestHelper

    def test_flatten_namespaces
      tree = parse_rbi(<<~RBI)
        class X; end
        module M; end
        module A
          class Y; end
          module N; end
          class B < X; end
          class C < Y
            include M
            extend N
          end
        end
      RBI

      tree.flatten_namespaces!

      assert_equal(<<~RBI, tree.string)
        class X; end
        module M; end
        module A; end
        class A::Y; end
        module A::N; end
        class A::B < X; end

        class A::C < A::Y
          include M
          extend A::N
        end
      RBI
    end
  end
end
