# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class NestSingletonMethodsTest < Minitest::Test
    def test_nest_singleton_methods_in_trees
      rbi = Tree.new
      rbi << Method.new("m1")
      rbi << Method.new("m2", is_singleton: true)
      rbi << Method.new("m3")
      rbi << Method.new("m4", is_singleton: true)

      rbi.nest_singleton_methods!

      assert_equal(<<~RBI, rbi.string)
        def m1; end
        def m3; end

        class << self
          def m2; end
          def m4; end
        end
      RBI
    end

    def test_nest_singleton_methods_in_scopes
      rbi = Tree.new
      scope1 = Module.new("Foo")
      scope1 << Method.new("m1")
      scope1 << Method.new("m2", is_singleton: true)
      scope2 = Class.new("Bar")
      scope2 << Method.new("m3")
      scope2 << Method.new("m4", is_singleton: true)
      rbi << scope1
      rbi << scope2

      rbi.nest_singleton_methods!

      assert_equal(<<~RBI, rbi.string)
        module Foo
          def m1; end

          class << self
            def m2; end
          end
        end

        class Bar
          def m3; end

          class << self
            def m4; end
          end
        end
      RBI
    end

    def test_nest_singleton_methods_in_singleton_classes
      rbi = Tree.new
      scope1 = SingletonClass.new
      scope1 << Method.new("m1", is_singleton: true)
      scope2 = SingletonClass.new
      scope2 << Method.new("m2", is_singleton: true)
      scope1 << scope2
      rbi << scope1

      rbi.nest_singleton_methods!

      assert_equal(<<~RBI, rbi.string)
        class << self
          class << self
            class << self
              def m2; end
            end
          end

          class << self
            def m1; end
          end
        end
      RBI
    end

    def test_nest_does_not_nest_other_nodes
      rbi = Tree.new
      scope1 = Module.new("Foo")
      scope1 << Const.new("C1", "42")
      scope1 << Module.new("M1")
      scope1 << Helper.new("h1")
      scope2 = Class.new("Bar")
      scope2 << Include.new("I1")
      scope2 << Extend.new("E1")
      rbi << scope1
      rbi << scope2

      rbi.nest_singleton_methods!

      assert_equal(<<~RBI, rbi.string)
        module Foo
          C1 = 42
          module M1; end
          h1!
        end

        class Bar
          include I1
          extend E1
        end
      RBI
    end
  end
end
