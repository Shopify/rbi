# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class GroupVisibilityNodesTest < Minitest::Test
    def test_groups_nodes_after_visibility_modifiers
      tree = parse_rbi(<<~RBI)
        class Foo
          def public_method; end

          private

          def private_method1; end
          def private_method2; end

          protected

          def protected_method; end
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)

      # Check structure
      foo_class = tree.nodes.first
      assert_instance_of(Class, foo_class)

      # First node should be the public method (not in a group)
      assert_instance_of(Method, foo_class.nodes[0])
      assert_equal("public_method", foo_class.nodes[0].name)

      # Second node should be a VisibilityGroup for private
      assert_instance_of(VisibilityGroup, foo_class.nodes[1])
      private_group = foo_class.nodes[1]
      assert(private_group.private?)
      assert_equal(2, private_group.nodes.size)
      assert_equal("private_method1", private_group.nodes[0].name)
      assert_equal("private_method2", private_group.nodes[1].name)

      # Third node should be a VisibilityGroup for protected
      assert_instance_of(VisibilityGroup, foo_class.nodes[2])
      protected_group = foo_class.nodes[2]
      assert(protected_group.protected?)
      assert_equal(1, protected_group.nodes.size)
      assert_equal("protected_method", protected_group.nodes[0].name)
    end

    def test_handles_multiple_visibility_markers
      tree = parse_rbi(<<~RBI)
        class Foo
          private
          def a; end

          private
          def b; end
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)

      foo_class = tree.nodes.first

      # Should have two separate VisibilityGroups
      assert_equal(2, foo_class.nodes.size)
      assert_instance_of(VisibilityGroup, foo_class.nodes[0])
      assert_instance_of(VisibilityGroup, foo_class.nodes[1])
    end

    def test_preserves_comments_on_visibility_modifier
      tree = parse_rbi(<<~RBI)
        class Foo
          # This is a comment
          private

          def private_method; end
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)

      foo_class = tree.nodes.first
      private_group = foo_class.nodes.first

      assert_instance_of(VisibilityGroup, private_group)
      assert_equal(1, private_group.comments.size)
      assert_equal("This is a comment", private_group.comments.first.text)
    end

    def test_handles_empty_visibility_groups
      tree = parse_rbi(<<~RBI)
        class Foo
          def public_method; end

          private
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)

      foo_class = tree.nodes.first

      # Should have the public method and an empty private group
      assert_equal(2, foo_class.nodes.size)
      assert_instance_of(Method, foo_class.nodes[0])
      assert_instance_of(VisibilityGroup, foo_class.nodes[1])
      assert(foo_class.nodes[1].empty?)
    end

    def test_nested_scopes
      tree = parse_rbi(<<~RBI)
        class Outer
          private
          def outer_private; end

          class Inner
            private
            def inner_private; end
          end
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)

      outer_class = tree.nodes.first
      assert_instance_of(VisibilityGroup, outer_class.nodes[0])

      # The Inner class should be inside the private group
      private_group = outer_class.nodes[0]
      inner_class = private_group.nodes.last
      assert_instance_of(Class, inner_class)

      # Inner class should also have its visibility grouped
      assert_instance_of(VisibilityGroup, inner_class.nodes[0])
    end

    def test_enables_sorting_within_visibility_groups
      tree = parse_rbi(<<~RBI)
        class Foo
          private
          def zebra; end
          def apple; end
          def middle; end
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)
      tree.sort_nodes!

      foo_class = tree.nodes.first
      private_group = foo_class.nodes.first

      # Methods should be sorted within the visibility group
      assert_instance_of(VisibilityGroup, private_group)
      assert_equal(3, private_group.nodes.size)
      assert_equal("apple", private_group.nodes[0].name)
      assert_equal("middle", private_group.nodes[1].name)
      assert_equal("zebra", private_group.nodes[2].name)
    end

    def test_sorting_respects_visibility_group_boundaries
      tree = parse_rbi(<<~RBI)
        class Foo
          def public_method_z; end

          private
          def private_method_a; end

          public
          def public_method_a; end
        end
      RBI

      Rewriters::GroupVisibilityNodes.group(tree)
      tree.sort_nodes!

      foo_class = tree.nodes.first

      # Should maintain visibility group order but sort within each
      assert_equal(3, foo_class.nodes.size)

      # First: public method before any visibility groups
      assert_instance_of(Method, foo_class.nodes[0])
      assert_equal("public_method_z", foo_class.nodes[0].name)

      # Second: private group
      assert_instance_of(VisibilityGroup, foo_class.nodes[1])
      assert(foo_class.nodes[1].private?)

      # Third: public group
      assert_instance_of(VisibilityGroup, foo_class.nodes[2])
      assert(foo_class.nodes[2].public?)
    end

    private

    def parse_rbi(content)
      Parser.parse_string(content)
    end
  end
end
