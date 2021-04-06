# typed: strict
# frozen_string_literal: true

require "logger"

module RBI
  class CustomLogger < ::Logger
    extend T::Sig

    sig { params(level: Integer, quiet: T::Boolean, color: T::Boolean, out: IO).void }
    def initialize(level: INFO, quiet: false, color: true, out: $stderr)
      super(STDOUT, level: level, formatter: -> (severity, _datetime, _progname, msg) {
                                               colorize_severity(severity) + msg + "\n" unless quiet
                                             })
      @level = level
      @quiet = quiet
      @color = color
      @out = out
    end

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
end
