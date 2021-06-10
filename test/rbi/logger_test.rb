# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class LoggerTest < Minitest::Test
    include TestHelper

    def test_logger_without_color
      logger, out = self.logger(level: Logger::DEBUG)

      logger.error("message `highlight`")
      logger.success("message `highlight`")
      logger.hint("message `highlight`")
      logger.warn("message `highlight`")
      logger.info("message `highlight`")
      logger.debug("message `highlight`")

      assert_log(<<~OUT, out.string)
        Error: message `highlight`
        Success: message `highlight`
        Hint: message `highlight`
        Warning: message `highlight`
        Info: message `highlight`
        Debug: message `highlight`
      OUT
    end

    def test_logger_with_color
      logger, out = self.logger(level: Logger::DEBUG, color: true)

      logger.error("message `highlight`")
      logger.success("message `highlight`")
      logger.hint("message `highlight`")
      logger.warn("message `highlight`")
      logger.info("message `highlight`")
      logger.debug("message `highlight`")

      assert_log(<<~OUT, out.string)
        \e[0;31;49mError\e[0m: message \e[0;34;49mhighlight\e[0m
        \e[0;32;49mSuccess\e[0m: message \e[0;34;49mhighlight\e[0m
        \e[0;32;49mHint\e[0m: message \e[0;34;49mhighlight\e[0m
        \e[0;33;49mWarning\e[0m: message \e[0;34;49mhighlight\e[0m
        \e[0;37;49mInfo\e[0m: message \e[0;34;49mhighlight\e[0m
        \e[0;39;49mDebug\e[0m: message \e[0;34;49mhighlight\e[0m
      OUT
    end

    def test_logger_quiet
      logger, out = self.logger(level: Logger::DEBUG, quiet: true)

      logger.error("message `highlight`")
      logger.success("message `highlight`")
      logger.hint("message `highlight`")
      logger.warn("message `highlight`")
      logger.info("message `highlight`")
      logger.debug("message `highlight`")

      assert_empty(out.string)
    end
  end
end
