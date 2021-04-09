# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class DuplicatesTest < Minitest::Test
    include TestHelper

    def test_no_duplicates
      rb = <<~RB
        module A
          def foo; end
          def bar; end
        end
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      assert(res)
      assert_empty(errors)
    end

    def test_duplicates_in_same_scope
      rb = <<~RB
        module A
          def foo; end
          def foo; end # with a trailing comment
        end
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      assert_equal("Duplicate definitions for `foo`", errors.first&.message)
    end

    def test_duplicates_in_different_scopes
      rb = <<~RB
        module A
          def foo; end
        end

        module A
          def foo; end # with a trailing comment
        end
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      assert_equal("Duplicate definitions for `foo`", errors.first&.message)
    end

    def test_duplicates_in_root_scope
      rb = <<~RB
        def foo; end
        def foo; end # with a trailing comment
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      assert_equal("Duplicate definitions for `foo`", errors.first&.message)
    end
  end
end
