# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module TestCLI
    class MergeTest < Minitest::Test
      include TestHelper

      def test_merge_first_file_not_found
        project = self.project("test_merge_first_file_not_found")

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_empty(out)
        assert_equal(<<~ERR.strip, err.strip)
          Error: Can't read file `a.rb`.
        ERR
        refute(status)

        project.destroy
      end

      def test_merge_second_file_not_found
        project = self.project("test_merge_second_file_not_found")
        project.write("a.rb", "")

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_empty(out)
        assert_equal(<<~ERR.strip, err.strip)
          Error: Can't read file `b.rb`.
        ERR
        refute(status)

        project.destroy
      end

      def test_merge_first_file_parse_error
        project = self.project("test_merge_first_file_parse_error")
        project.write("a.rb", "def foo")
        project.write("b.rb", "")

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_empty(out)
        assert_equal(<<~ERR.strip, err.strip)
          Error: Parse error in `a.rb`: unexpected token $end.
        ERR
        refute(status)

        project.destroy
      end

      def test_merge_second_file_parse_error
        project = self.project("test_merge_second_file_parse_error")
        project.write("a.rb", "")
        project.write("b.rb", "def foo")

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_empty(out)
        assert_equal(<<~ERR.strip, err.strip)
          Error: Parse error in `b.rb`: unexpected token $end.
        ERR
        refute(status)

        project.destroy
      end

      def test_merge_empty_files
        project = self.project("test_merge_empty_files")
        project.write("a.rb", "")
        project.write("b.rb", "")

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_empty(out.strip)
        assert_empty(err)
        assert(status)

        project.destroy
      end

      def test_merge_empty_files_with_comments
        project = self.project("test_merge_empty_files_with_comments")
        project.write("a.rb", <<~RBI)
          # typed: true
          #
          # Comment 1
        RBI
        project.write("b.rb", <<~RBI)
          # typed: true
          #
          # Comment 2
        RBI

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_equal(<<~RBI.strip, out.strip)
          # typed: true
          #
          # Comment 1
          # Comment 2
        RBI
        assert_empty(err)
        assert(status)

        project.destroy
      end

      def test_merge_files_with_conflicts
        project = self.project("test_merge_files_with_conflicts")
        project.write("a.rb", <<~RBI)
          class A
            def a1; end
            def a2; end
            def a3(x); end
          end

          class A::B
            def b1; end
            def b2; end
          end
        RBI

        project.write("b.rb", <<~RBI)
          class A
            sig { void }
            def a1; end

            def a3(x, y); end
            def a4; end
          end

          module A::B; end
        RBI

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb --no-color")
        assert_equal(<<~RBI.strip, out.strip)
          class A
            sig { void }
            def a1; end

            def a2; end
            <<<<<<< a.rb
            def a3(x); end
            =======
            def a3(x, y); end
            >>>>>>> b.rb
            def a4; end
          end

          <<<<<<< a.rb
          class A::B
          =======
          module A::B; end
          >>>>>>> b.rb
            def b1; end
            def b2; end
          end
        RBI
        assert_equal(<<~ERR.strip, err.strip)
          Error: Merge conflict between definitions `a.rb#::A#a3(x)` and `b.rb#::A#a3(x, y)`
          Error: Merge conflict between definitions `a.rb#::A::B` and `b.rb#::A::B`
        ERR
        refute(status)

        project.destroy
      end

      def test_merge_files_and_save_output
        project = self.project("test_merge_files_and_save_output")
        project.write("a.rb", <<~RBI)
          class A
            def a1; end
            def a2; end
          end
        RBI

        project.write("b.rb", <<~RBI)
          class A
            def a1; end
            def a2(x); end
          end
        RBI

        out, err, status = project.bundle_exec("rbi merge a.rb b.rb -o out.rbi --no-color")

        assert_empty(out)
        assert_equal(<<~ERR.strip, err.strip)
          Error: Merge conflict between definitions `a.rb#::A#a2()` and `b.rb#::A#a2(x)`
        ERR
        refute(status)

        rbi = File.read(project.absolute_path("out.rbi"))
        assert_equal(<<~RBI.strip, rbi.strip)
          class A
            def a1; end
            <<<<<<< a.rb
            def a2; end
            =======
            def a2(x); end
            >>>>>>> b.rb
          end
        RBI

        project.destroy
      end
    end
  end
end
