# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class NestSingletonMethodsTest < Minitest::Test
    include TestHelper

    def test_nest_singleton_methods_in_trees
      tree = parse_rbi(<<~RBI)
        def m1; end
        def self.m2; end
        def m3; end
        def self.m4; end
      RBI

      tree.nest_singleton_methods!

      assert_equal(<<~RBI, tree.string)
        def m1; end
        def m3; end

        class << self
          def m2; end
          def m4; end
        end
      RBI
    end

    def test_nest_singleton_methods_in_scopes
      tree = parse_rbi(<<~RBI)
        module Foo
          def m1; end
          def self.m2; end
        end

        class Bar
          def m3; end
          def self.m4; end
        end
      RBI

      tree.nest_singleton_methods!

      assert_equal(<<~RBI, tree.string)
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
      tree = parse_rbi(<<~RBI)
        class << self
          def self.m1; end
          class << self
            def self.m2; end
          end
        end
      RBI

      tree.nest_singleton_methods!

      assert_equal(<<~RBI, tree.string)
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
      rbi = <<~RBI
        module Foo
          C1 = T.let(T.unsafe(nil), T.untyped)
          module M1; end
          h1!
        end

        class Bar
          include I1
          extend E1
        end
      RBI

      tree = parse_rbi(rbi)
      tree.nest_singleton_methods!

      assert_equal(rbi, tree.string)
    end
  end
end
