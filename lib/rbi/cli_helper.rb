# typed: strict
# frozen_string_literal: true

require "thor"

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { params(msg: String, logger: Logger, blk: T.proc.returns(T.untyped)).returns(T.untyped) }
    def measure_duration(msg, logger, &blk)
      if logger.level == ::Logger::DEBUG
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ret = blk.call
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        logger.info(format("#{msg} completed in %5.2fs", end_time - start_time))

        ret
      else
        blk.call
      end
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? ::Logger::Severity::DEBUG : ::Logger::Severity::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end
  end
end
