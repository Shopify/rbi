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
          def foo; end
        end
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      assert_equal("Duplicate definitions found for `foo`: -:2:2-2:14,-:3:2-3:14", errors.first.to_s)
    end

    def test_duplicates_in_different_scopes
      rb = <<~RB
        module A
          def foo; end
        end

        module A
          def foo; end
        end
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      assert_equal("Duplicate definitions found for `foo`: -:2:2-2:14,-:6:2-6:14", errors.first.to_s)
    end

    def test_duplicates_in_root_scope
      rb = <<~RB
        def foo; end
        def foo; end
      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      assert_equal("Duplicate definitions found for `foo`: -:1:0-1:12,-:2:0-2:12", errors.first.to_s)
    end
  end
end
