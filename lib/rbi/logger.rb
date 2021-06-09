# typed: strict
# frozen_string_literal: true

module RBI
  class Logger
    extend T::Sig

    ERROR = 6
    SUCCESS = 5
    HINT = 4
    WARN = 3
    INFO = 2
    DEBUG = 1

    sig { params(level: Integer, quiet: T::Boolean, color: T::Boolean, out: T.any(IO, StringIO)).void }
    def initialize(level: INFO, quiet: false, color: true, out: $stderr)
      @level = level
      @quiet = quiet
      @color = color
      @out = out
    end

    sig { params(message: String, label: T.nilable(String)).void }
    def error(message, label: "Error")
      log(ERROR, message, label: label, label_color: :red)
    end

    sig { params(message: String, label: T.nilable(String)).void }
    def success(message, label: "Success")
      log(SUCCESS, message, label: label, label_color: :green)
    end

    sig { params(message: String, label: T.nilable(String)).void }
    def hint(message, label: "Hint")
      log(HINT, message, label: label, label_color: :green)
    end

    sig { params(message: String, label: T.nilable(String)).void }
    def warn(message, label: "Warning")
      log(WARN, message, label: label, label_color: :yellow)
    end

    sig { params(message: String, label: T.nilable(String)).void }
    def info(message, label: "Info")
      log(INFO, message, label: label, label_color: :white)
    end

    sig { params(message: String, label: T.nilable(String)).void }
    def debug(message, label: "Debug")
      log(DEBUG, message, label: label, label_color: :gray)
    end

    sig do
      params(
        level: Integer,
        message: String,
        label: T.nilable(String),
        label_color: T.nilable(Symbol)
      ).void
    end
    def log(level, message, label: nil, label_color: nil)
      if label
        puts(level, colorize(label, label_color), ": ", highlight(message))
      else
        puts(level, highlight(message))
      end
    end

    sig { params(string: String, color: T.nilable(Symbol)).returns(String) }
    def colorize(string, color)
      return string unless @color
      string = string.colorize(color) if color
      highlight(string)
    end

    sig { params(string: String).returns(String) }
    def highlight(string)
      return string unless @color
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

    private

    sig { params(level: Integer, string: String).void }
    def puts(level, *string)
      return if @quiet || level < @level
      @out.puts string.join
    end
  end
end
