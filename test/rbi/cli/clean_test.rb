# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module CliTest
    class CleanTest < Minitest::Test
      include TestHelper

      def test_clean
        project = self.project("test_clean")
        project.write("sorbet/rbi/gems/foo@1.0.0.rbi")
        project.write("sorbet/rbi/gems/foo@2.0.0.rbi")
        project.write("sorbet/rbi/gems/bar@1.0.0.rbi")

        logger, _ = self.logger
        context = Context.new(project.path, logger: logger)
        context.clean

        out, err, status = project.bundle_exec("rbi clean --no-color")
        assert_empty(out)
        assert_equal(<<~ERR, err)
          Success: Clean `sorbet/rbi/gems` directory
        ERR
        assert(status)

        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@1.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/foo@2.0.0.rbi"))
        refute(File.file?("#{project.path}/sorbet/rbi/gems/bar@1.0.0.rbi"))

        project.destroy
      end
    end
  end
end
