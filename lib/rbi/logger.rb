# typed: strict
# frozen_string_literal: true

module RBI
  class Logger
    extend T::Sig

    INTERNAL = 0
    ERROR = 1
    WARN = 2
    INFO = 3
    DEBUG = 4

    sig { returns(Integer) }
    attr_reader :level

    sig { returns(T::Boolean) }
    attr_reader :quiet

    sig { returns(T::Boolean) }
    attr_reader :color

    sig { params(level: Integer, quiet: T::Boolean, color: T::Boolean, out: IO, time: T::Boolean).void }
    def initialize(level: INFO, quiet: false, color: true, out: $stderr, time: false)
      @level = level
      @quiet = quiet
      @color = color
      @out = out
      @time = time
    end

    sig { params(message: String).void }
    def error(message)
      puts(ERROR, colorize("Error", :red), ": ", message)
    end

    sig { params(message: String).void }
    def warn(message)
      puts(WARN, colorize("Warning", :yellow), ": ", message)
    end

    sig { params(message: String).void }
    def info(message)
      puts(INFO, message)
    end

    sig { params(message: String).void }
    def debug(message)
      puts(DEBUG, colorize(message, :light_black))
    end

    sig { params(message: String).void }
    def say(message)
      puts(INTERNAL, message)
    end

    sig { params(string: String, color: Symbol).returns(String) }
    def colorize(string, color)
      return string unless @color
      string.colorize(color)
    end

    sig { params(step: String, blk: T.proc.returns(T.untyped)).returns(T.untyped) }
    def time(step, &blk)
      if @time
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ret = blk.call
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        puts(@level, format("#{step} completed in %5.2fs", end_time - start_time))

        ret
      else
        blk.call
      end
    end

    private

    sig { params(level: Integer, string: String).void }
    def puts(level, *string)
      @out.puts string.join unless level > @level || @quiet
    end
  end
end
