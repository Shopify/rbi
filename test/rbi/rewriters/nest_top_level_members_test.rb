# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class NestTopLevelMembersTest < Minitest::Test
    include TestHelper

    def test_nest_top_level_members
      tree = parse_rbi(<<~RBI)
        module Foo
          def m1; end
        end

        def m2; end
        def self.m3; end
        attr_reader :foo
        send!

        class << self; end
      RBI

      tree.nest_top_level_members!

      assert_equal(<<~RBI, tree.string)
        module Foo
          def m1; end
        end

        class << self; end

        class Object
          def m2; end
          def self.m3; end
          attr_reader :foo
          send!
        end
      RBI
    end

    def test_nest_top_level_members_reuse_the_same_class
      tree = parse_rbi(<<~RBI)
        def foo; end
        class Foo; end
        def bar; end
      RBI

      tree.nest_top_level_members!

      assert_equal(<<~RBI, tree.string)
        class Foo; end

        class Object
          def foo; end
          def bar; end
        end
      RBI
    end

    def test_nest_top_level_members_duplicate_existing_object_class
      tree = parse_rbi(<<~RBI)
        class Object
          def foo; end
        end
        def bar; end
        class Object
          def baz; end
        end
      RBI

      tree.nest_top_level_members!

      assert_equal(<<~RBI, tree.string)
        class Object
          def foo; end
        end

        class Object
          def baz; end
        end

        class Object
          def bar; end
        end
      RBI
    end
  end
end
