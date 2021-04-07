# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class DuplicatesTest < Minitest::Test
    include TestHelper

    def setup
      @reader, @writer = IO.pipe
      @logger = logger(color: false, logdev: @writer)
    end

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
          def foo;end
          def foo; end
        end
      RB

      exp = <<~RB
        Error: Duplicate definitions for `foo`

          -:2:

          -:3:

      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      error = errors.first
      assert_log(exp, @reader, @writer) { @logger.error(error&.message, error&.sections) }
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

      exp = <<~RB
        Error: Duplicate definitions for `foo`

          -:2:

          -:6:

      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      error = errors.first
      assert_log(exp, @reader, @writer) { @logger.error(error&.message, error&.sections) }
    end

    def test_duplicates_in_root_scope
      rb = <<~RB
        def foo; end
        def foo; end
      RB

      exp = <<~RB
        Error: Duplicate definitions for `foo`

          -:1:

          -:2:

      RB

      tree = parse(rb)
      res, errors = Validators::Duplicates.validate([tree])
      refute(res)
      assert_equal(1, errors.size)
      error = errors.first
      assert_log(exp, @reader, @writer) { @logger.error(error&.message, error&.sections) }
    end
  end
end
