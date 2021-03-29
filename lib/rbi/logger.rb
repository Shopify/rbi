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

      sig do
        params(severity: String, _time: Time, _progname: T.nilable(String), msg: T.untyped).returns(T.nilable(String))
      end
      def call(severity, _time, _progname, msg)
        colorize_severity(severity) + msg.to_s + "\n" unless @quiet
      end

      sig { params(string: String, color: T.nilable(Symbol)).returns(String) }
      def colorize(string, color)
        return string unless @color
        string = string.colorize(color) if color
        highlight(string)
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

      sig { params(string: String).returns(String) }
      def highlight(string)
        res = StringIO.new
        word = StringIO.new
        in_ticks = T.let(false, T::Boolean)
        string.chars.each do |c|
          if c == "`" && !in_ticks
            in_ticks = true
          elsif c == "`" && in_ticks
            in_ticks = false
            res << colorize(word.string, :blue)
            word = StringIO.new
          elsif in_ticks
            word << c
          else
            res << c
          end
        end
        res.string
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
      formatter: Formatter.new(quiet: quiet, color: color))
      super(logdev, level: level, formatter: formatter)
      @level = level
      @quiet = quiet
      @color = color
    end

    private

    sig { params(string: String, color: T.nilable(Symbol)).returns(String) }
    def colorize(string, color = nil)
      T.cast(@formatter, Formatter).colorize(string, color)
    end
  end
end
