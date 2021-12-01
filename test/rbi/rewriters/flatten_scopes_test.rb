# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FlattenScopesTest < Minitest::Test
    def test_flatten_scopes_with_empty_scopes
      rbi = RBI::Tree.new
      scope1 = RBI::Module.new("A")
      scope2 = RBI::Class.new("B")
      scope3 = RBI::Class.new("C")
      scope4 = RBI::Module.new("D")
      scope5 = RBI::Module.new("E")
      scope3 << scope4
      scope2 << scope3
      scope1 << scope2
      rbi << scope1
      rbi << scope5

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
      rbi = RBI::Tree.new
      scope1 = RBI::Module.new("A")
      scope1 << RBI::Const.new("A1", "42")
      scope2 = RBI::Class.new("B")
      scope3 = RBI::Class.new("C")
      scope3 << RBI::Const.new("C1", "42")
      scope4 = RBI::Module.new("D")
      scope5 = RBI::Module.new("E")
      scope5 << RBI::Const.new("E1", "42")
      scope3 << scope4
      scope2 << scope3
      scope1 << scope2
      rbi << scope1
      rbi << scope5

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
      rbi = RBI::Tree.new
      scope1 = RBI::Module.new("A")
      scope2 = RBI::Class.new("B")
      scope3 = RBI::Class.new("C")
      scope3_singleton = RBI::SingletonClass.new
      scope3_singleton << RBI::Method.new("m1")
      scope4 = RBI::Module.new("D")
      scope5 = RBI::Module.new("E")
      scope3 << scope4
      scope3 << scope3_singleton
      scope2 << scope3
      scope1 << scope2
      rbi << scope1
      rbi << scope5

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
  end
end
