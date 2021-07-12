# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module CliTest
    class CleanTest < Minitest::Test
      include TestHelper

      def test_clean_shims
        project = self.project("test_clean_shims")

        project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
          class Foo
            attr_reader :foo
          end
        RBI

        project.write("sorbet/rbi/gems/bar@2.0.0.rbi", <<~RBI)
          module Bar
            def bar; end
          end
        RBI

        project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
          class Foo
            attr_reader :foo
          end
        RBI

        project.write("sorbet/rbi/shims/bar.rbi", <<~RBI)
          module Bar
            def foo; end
            def bar; end
          end
        RBI

        project.write("sorbet/rbi/shims/baz.rbi", <<~RBI)
          BAZ = 42
        RBI

        out, err, status = project.bundle_exec("rbi clean-shims -v --no-color")

        assert_empty(out)
        assert_equal(<<~ERR, err)
          Debug: Deleted #bar() duplicate from sorbet/rbi/gems/bar@2.0.0.rbi:2:2-2:14
          Info: Cleaned sorbet/rbi/shims/bar.rbi
          Debug: Nothing to clean in sorbet/rbi/shims/baz.rbi
          Debug: Deleted .attr_reader(:foo) duplicate from sorbet/rbi/gems/foo@1.0.0.rbi:2:2-2:18
          Debug: Deleted ::Foo duplicate from sorbet/rbi/gems/foo@1.0.0.rbi:1:0-3:3
          Info: Deleted empty file sorbet/rbi/shims/foo.rbi
          Success: Cleaned `sorbet/rbi/shims` directory
        ERR
        assert(status)

        refute(File.file?("#{project.path}/sorbet/rbi/shims/foo.rbi"))

        bar_content = File.read("#{project.path}/sorbet/rbi/shims/bar.rbi")
        assert_equal(<<~RBI, bar_content)
          module Bar
            def foo; end
          end
        RBI

        baz_content = File.read("#{project.path}/sorbet/rbi/shims/baz.rbi")
        assert_equal(<<~RBI, baz_content)
          BAZ = 42
        RBI

        project.destroy
      end
    end
  end
end
