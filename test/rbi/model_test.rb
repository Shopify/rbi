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
      cA = Class.new("A")
      cB = Class.new("B")

      tree << tree1
      tree1 << cA
      cA << tree2
      tree2 << cB

      assert_nil(cA.parent_scope)
      assert_equal(cA, cB.parent_scope)
    end

    def test_scopes_names
      tree = Tree.new
      cA = Class.new("A")
      cB = Class.new("B")

      cA << cB
      tree << cA

      assert_equal("::A", cA.qualified_name)
      assert_equal("::A::B", cB.qualified_name)
    end
  end
end