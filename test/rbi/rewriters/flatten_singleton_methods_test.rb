# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FlattenSingletonMethodsTest < Minitest::Test
    include TestHelper

    def test_flatten_singleton_methods_in_trees
      tree = parse_rbi(<<~RBI)
        def m1; end
        def m3; end

        class << self
          def m2; end
          def m4; end
        end
      RBI

      tree.flatten_singleton_methods!

      assert_equal(<<~RBI, tree.string)
        def m1; end
        def m3; end
        def self.m2; end
        def self.m4; end
      RBI
    end

    def test_flatten_singleton_methods_in_scopes
      tree = parse_rbi(<<~RBI)
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

      tree.flatten_singleton_methods!

      assert_equal(<<~RBI, tree.string)
        module Foo
          def m1; end
          def self.m2; end
        end

        class Bar
          def m3; end
          def self.m4; end
        end
      RBI
    end

    def test_flatten_singleton_methods_remove_empty_singleton_classes
      tree = parse_rbi(<<~RBI)
        class Foo
          class << self
            class << self
              class << self
              end
            end
          end
        end
      RBI

      tree.flatten_singleton_methods!

      assert_equal(<<~RBI, tree.string)
        class Foo; end
      RBI
    end

    def test_flatten_singleton_methods_in_first_level_of_singleton_classes
      tree = parse_rbi(<<~RBI)
        class << self
          def m1; end

          # will not be rewritten, singleton method in a singleton class
          def self.m2; end

          class << self
            class << self
              def m3; end
            end
          end

          class << self
            def m4; end
            def self.m5; end
          end
        end
      RBI

      tree.flatten_singleton_methods!

      assert_equal(<<~RBI, tree.string)
        class << self
          # will not be rewritten, singleton method in a singleton class
          def self.m2; end

          class << self
            def self.m3; end
          end

          class << self
            def self.m5; end
          end

          def self.m4; end
        end

        def self.m1; end
      RBI
    end

    def test_flatten_does_not_flatten_other_nodes
      rbi = <<~RBI
        module Foo
          C1 = 42
          module M1; end
          abtract!
        end

        class Bar
          include I1
          extend E1
        end
      RBI

      tree = parse_rbi(rbi)
      tree.flatten_singleton_methods!

      assert_equal(rbi, tree.string)
    end
  end
end
