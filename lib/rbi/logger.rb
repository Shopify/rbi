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

      sig { params(string: String, color: Symbol).returns(String) }
      def colorize(string, color)
        return string unless @color
        string.colorize(color)
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

    sig { params(message: String, sections: T::Array[Validators::Duplicates::Error::Section]).void }
    def error(message, sections)
      str = StringIO.new
      str << "#{message}\n"

      sections.each do |section|
        loc = section.loc
        next unless loc

        str << "\n"
        str << colorize("  #{loc.file}:#{loc.begin_line}:", :yellow)
        str << "\n"
        str << show_source(loc)
      end

      super(str.string)
    end

    sig { params(loc: Loc).returns(String) }
    def show_source(loc)
      file = loc.file
      return "" unless file && file != "-"

      str = StringIO.new
      source = File.read(file)
      lines = T.must(source.lines[(T.must(loc.begin_line) - 1)..(T.must(loc.end_line) - 1)])
      lines = [
        *lines[0..2],
        colorize("#{" " * T.must(lines[2]&.index(/[^ ]/))}...\n"),
        *lines[-3..lines.size],
      ] if lines.size > 10
      lines.each do |line|
        rjust = @color ? 23 : 9
        str << colorize("#{loc.begin_line} | ", :light_black).rjust(rjust)
        str << colorize(line.rstrip)
        str << "\n"
      end

      str.string
    end

    sig { params(string: String, color: T.nilable(Symbol)).returns(String) }
    def colorize(string, color = nil)
      return string unless color
      T.cast(@formatter, Formatter).colorize(string, color)
    end
  end
end
