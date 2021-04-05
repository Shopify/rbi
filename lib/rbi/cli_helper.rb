# typed: true
# frozen_string_literal: true

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Kernel

    sig { params(msg: String, logger: Logger, blk: T.proc.returns(T.untyped)).returns(T.untyped) }
    def measure_duration(msg, logger, &blk)
      if logger.level == Logger::DEBUG
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ret = blk.call
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        logger.info(format("#{msg} completed in %5.2fs", end_time - start_time))

        ret
      else
        blk.call
      end
    end
  end
end
