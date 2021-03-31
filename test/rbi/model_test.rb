# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class ModelTest < Minitest::Test
    include TestHelper

    def test_parent_scopes
      tree = Tree.new
      tree1 = Tree.new
      tree2 = Tree.new
      ca = Class.new("A")
      cb = Class.new("B")

      tree << tree1
      tree1 << ca
      ca << tree2
      tree2 << cb

      assert_nil(ca.parent_scope)
      assert_equal(ca, cb.parent_scope)
    end

    def test_scopes_names
      tree = Tree.new
      ca = Class.new("A")
      cb = Class.new("B")

      ca << cb
      tree << ca

      assert_equal("::A", ca.qualified_name)
      assert_equal("::A::B", cb.qualified_name)
    end
  end
end
