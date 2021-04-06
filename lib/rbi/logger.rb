# typed: strict
# frozen_string_literal: true

require "logger"

module RBI
  class Logger < ::Logger
    extend T::Sig

    class Formatter < ::Logger::Formatter
      extend T::Sig

      sig { params(quiet: T::Boolean, color: T::Boolean).void }
      def initialize(quiet: false, color: true)
        super()

        @quiet = quiet
        @color = color
      end

      sig { params(severity: String, time: Time, progname: T.nilable(String), msg: T.untyped).returns(T.nilable(String)) }
      def call(severity, time, progname, msg)
        colorize_severity(severity) + msg.to_s + "\n" unless @quiet
      end

      private

      sig { params(severity: String).returns(String) }
      def colorize_severity(severity)
        case severity
        when "ERROR"
          colorize("Error", :red) + ": "
        when "WARN"
          colorize("Warning", :yellow) + ": "
        when "INFO"
          "Info: "
        when "DEBUG"
          colorize("Debug", :light_black) + ": "
        else
          ""
        end
      end

      sig { params(string: String, color: Symbol).returns(String) }
      def colorize(string, color)
        return string unless @color
        string.colorize(color)
      end
    end

    sig do
      params(
        level: Integer,
        quiet: T::Boolean,
        color: T::Boolean,
        logdev: T.any(String, IO, StringIO, NilClass),
        formatter: Formatter
      ).void
    end
    def initialize(level: INFO,
                   quiet: false,
                   color: true,
                   logdev: $stdout,
                   formatter: Formatter.new(quiet: quiet, color: color)
                  )
      # require 'byebug'; byebug
      super(logdev, level: level, formatter: formatter)
      @level = level
      @quiet = quiet
      @color = color
    end
  end
end
