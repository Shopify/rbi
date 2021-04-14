# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class DuplicatesTest < Minitest::Test
    include TestHelper

    def setup
      @project = project("duplicates_test")
    end

    def teardown
      @project.destroy
    end

    def test_no_duplicates
      @project.write("sorbet/rbi/test.rbi", <<~RB)
        module A
          def foo; end
          def bar; end
        end
      RB

      expected = <<~OUT
        Info: No duplicate RBI definitions were found.
      OUT

      out, status = @project.run("rbi validate --no-color")
      assert(status)
      assert_equal(expected, out)
    end

    def test_duplicates_in_same_scope
      @project.write("sorbet/rbi/test.rbi", <<~RB)
        module A
          def foo; end
          def foo; end # with a trailing comment
        end
      RB

      expected = <<~OUT
        Error: Duplicate definitions for `foo`

          sorbet/rbi/test.rbi:2:
             2 |   def foo; end

          sorbet/rbi/test.rbi:3:
             3 |   def foo; end # with a trailing comment

      OUT

      out, status = @project.run("rbi validate --no-color")
      refute(status)
      assert_equal(expected, out)
    end

    def test_duplicates_in_different_scopes
      @project.write("sorbet/rbi/test.rbi", <<~RB)
        module A
          def foo; end
        end

        module A
          def foo; end # with a trailing comment
        end
      RB

      expected = <<~OUT
        Error: Duplicate definitions for `foo`

          sorbet/rbi/test.rbi:2:
             2 |   def foo; end

          sorbet/rbi/test.rbi:6:
             6 |   def foo; end # with a trailing comment

      OUT

      out, status = @project.run("rbi validate --no-color")
      refute(status)
      assert_equal(expected, out)
    end

    def test_duplicates_in_root_scope
      @project.write("sorbet/rbi/test.rbi", <<~RB)
        def foo; end
        def foo; end # with a trailing comment
      RB

      expected = <<~OUT
        Error: Duplicate definitions for `foo`

          sorbet/rbi/test.rbi:1:
             1 | def foo; end

          sorbet/rbi/test.rbi:2:
             2 | def foo; end # with a trailing comment

      OUT

      out, status = @project.run("rbi validate --no-color")
      refute(status)
      assert_equal(expected, out)
    end

    def test_duplicates_in_different_files
      @project.write("sorbet/rbi/a.rbi", <<~RB)
        module A
          def foo; end # in a.rbi
        end
      RB

      @project.write("sorbet/rbi/b.rbi", <<~RB)
        module A
          def foo; end # in b.rbi
        end
      RB

      expected = <<~OUT
        Error: Duplicate definitions for `foo`

          sorbet/rbi/a.rbi:2:
             2 |   def foo; end # in a.rbi

          sorbet/rbi/b.rbi:2:
             2 |   def foo; end # in b.rbi

      OUT

      out, status = @project.run("rbi validate --no-color")
      refute(status)
      assert_equal(expected, out)
    end

    def test_duplicates_with_attr_methods
      @project.write("sorbet/rbi/test.rbi", <<~RB)
        module A
          attr_accessor :foo
          def foo; end
          def foo=; end
          attr_reader :foo, :bar
          def bar; end
          attr_writer :baz
          def baz=; end
        end
      RB

      expected = <<~OUT
        Error: Duplicate definitions for `foo`

          sorbet/rbi/test.rbi:2:
             2 |   attr_accessor :foo

          sorbet/rbi/test.rbi:3:
             3 |   def foo; end

          sorbet/rbi/test.rbi:5:
             5 |   attr_reader :foo, :bar

        Error: Duplicate definitions for `foo`

          sorbet/rbi/test.rbi:2:
             2 |   attr_accessor :foo

          sorbet/rbi/test.rbi:4:
             4 |   def foo=; end

        Error: Duplicate definitions for `bar`

          sorbet/rbi/test.rbi:5:
             5 |   attr_reader :foo, :bar

          sorbet/rbi/test.rbi:6:
             6 |   def bar; end

        Error: Duplicate definitions for `baz`

          sorbet/rbi/test.rbi:7:
             7 |   attr_writer :baz

          sorbet/rbi/test.rbi:8:
             8 |   def baz=; end

      OUT

      out, status = @project.run("rbi validate --no-color")
      refute(status)
      assert_equal(expected, out)
    end
  end
end
