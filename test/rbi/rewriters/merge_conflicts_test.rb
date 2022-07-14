# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class MergeConflictsTest < Minitest::Test
    def test_merge_conflicts_keep_left
      rbi1 = Parser.parse_string(<<~RBI)
        module Foo
          A = 10

          class Bar
            def m1; end

            sig { void }
            def m2; end

            def m3; end
          end
        end
      RBI

      rbi2 = Parser.parse_string(<<~RBI)
        module Foo
          A = 42

          module Bar
            def m1(x); end

            sig { returns(Integer) }
            def m2; end

            def m4; end
          end
        end
      RBI

      res = rbi1.merge(rbi2, keep: Rewriters::MergeConflicts::Keep::LEFT)

      assert_equal(<<~RBI, res.string)
        module Foo
          A = 10

          class Bar
            def m1; end

            sig { void }
            def m2; end

            def m3; end
            def m4; end
          end
        end
      RBI
    end

    def test_merge_conflicts_keep_right
      rbi1 = Parser.parse_string(<<~RBI)
        module Foo
          A = 10

          class Bar
            def m1; end

            sig { void }
            def m2; end

            def m3; end
          end
        end
      RBI

      rbi2 = Parser.parse_string(<<~RBI)
        module Foo
          A = 42

          module Bar
            def m1(x); end

            sig { returns(Integer) }
            def m2; end

            def m4; end
          end
        end
      RBI

      res = rbi1.merge(rbi2, keep: Rewriters::MergeConflicts::Keep::RIGHT)

      assert_equal(<<~RBI, res.string)
        module Foo
          A = 42

          module Bar
            def m1(x); end

            sig { returns(Integer) }
            def m2; end

            def m3; end
            def m4; end
          end
        end
      RBI
    end

    def test_merge_trees_with_singleton_classes
      rbi1 = Parser.parse_string(<<~RBI)
        module Foo
          class << self
            def m1; end

            sig { void }
            def m2; end
          end
        end
      RBI

      rbi2 = Parser.parse_string(<<~RBI)
        module Foo
          def self.m1(x); end

          sig { returns(Integer) }
          def self.m2; end
        end
      RBI

      res = rbi1.merge(rbi2, keep: Rewriters::MergeConflicts::Keep::RIGHT)

      assert_equal(<<~RBI, res.string)
        module Foo
          class << self
            def m1(x); end

            sig { returns(Integer) }
            def m2; end
          end
        end
      RBI
    end

    def test_merge_trees_with_singleton_classes_with_scope
      rbi1 = Parser.parse_string(<<~RBI)
        module Foo
          def self.m1(x); end

          sig { returns(Integer) }
          def self.m2; end
        end
      RBI

      rbi2 = Parser.parse_string(<<~RBI)
        module Foo
          class << self
            def m1; end

            sig { void }
            def m2; end
          end
        end
      RBI

      res = rbi1.merge(rbi2, keep: Rewriters::MergeConflicts::Keep::RIGHT)

      assert_equal(<<~RBI, res.string)
        module Foo
          class << self
            def m1; end

            sig { void }
            def m2; end
          end
        end
      RBI
    end
  end
end
