# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class CLITest < Minitest::Test
    include TestHelper

    def setup
      @project = stub_project("test_cli")
    end

    def teardown
      @project.destroy
    end

    def test_display_current_version_short_option
      out, _ = @project.rbi("-v")
      assert_equal("RBI v#{RBI::VERSION}", out&.strip)
    end

    def test_display_current_version_long_option
      out, _ = @project.rbi("--version")
      assert_equal("RBI v#{RBI::VERSION}", out&.strip)
    end

    def test_display_help_long_option
      out, _ = @project.rbi("--help")
      assert_log(<<~OUT, out)
        Commands:
          rbi --version       # Show version
          rbi help [COMMAND]  # Describe available commands or one specific command
      OUT
    end
  end
end
