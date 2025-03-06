# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class LocTest < Minitest::Test
    TEST_FILE_PATH = "tmp/rbi/tests/source.rbi"

    TEST_FILE_CONTENT = <<~RBI
      # typed: true

      class Foo
        def foo; end
      end

      class Bar; end
      class Baz; end
    RBI

    def setup
      dir = ::File.dirname(TEST_FILE_PATH)
      FileUtils.mkdir_p(dir)
      ::File.write(TEST_FILE_PATH, TEST_FILE_CONTENT)
    end

    def teardown
      FileUtils.rm_rf(TEST_FILE_PATH)
    end

    def test_loc_to_s_display_end_line_and_column_if_set
      loc = Loc.new(file: "foo.rb", begin_line: 1, begin_column: 2, end_line: 3, end_column: 4)
      assert_equal("foo.rb:1:2-3:4", loc.to_s)
    end

    def test_loc_to_s_does_not_display_end_line_and_column_if_not_set
      loc = Loc.new(file: "foo.rb", begin_line: 1, begin_column: 2)
      assert_equal("foo.rb:1:2", loc.to_s)
    end

    def test_loc_source_without_file_returns_nil
      loc = Loc.new(file: nil)
      assert_nil(loc.source)
    end

    def test_loc_source_with_unexisting_file_returns_nil
      loc = Loc.new(file: "tmp/rbi/tests/not_found.rbi")
      assert_nil(loc.source)
    end

    def test_loc_source_from_file_without_lines
      loc = Loc.new(file: TEST_FILE_PATH)
      assert_equal(TEST_FILE_CONTENT, loc.source)
    end

    def test_loc_source_from_file_between_lines
      loc = Loc.new(file: TEST_FILE_PATH, begin_line: 3, end_line: 5)
      assert_equal(<<~RBI, loc.source)
        class Foo
          def foo; end
        end
      RBI
    end

    def test_loc_source_from_file_at_line
      loc = Loc.new(file: TEST_FILE_PATH, begin_line: 7, end_line: 7)
      assert_equal(<<~RBI, loc.source)
        class Bar; end
      RBI
    end

    def test_loc_source_from_file_out_of_range
      loc = Loc.new(file: TEST_FILE_PATH, begin_line: -10, end_line: 100)
      assert_equal(TEST_FILE_CONTENT, loc.source)
    end
  end
end
