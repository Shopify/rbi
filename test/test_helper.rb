# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rbi"
require "minitest/test"

module RBI
  module TestHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Minitest::Test

    sig { params(string: String).returns(Tree) }
    def parse(string)
      Parser.parse_string(string)
    end

    sig { params(strings: String, opts: T::Hash[Symbol, T.untyped]).returns(String) }
    def print(*strings, opts: {})
      out = StringIO.new
      rbis = strings.map { |string| parse(string,) }
      rbis.map { |rbi| T.unsafe(rbi).print(out: out, **opts) }
      out.string
    end

    sig { params(exp: String, string: String, opts: T::Hash[Symbol, T.untyped]).void }
    def assert_print_equal(exp, string, opts: {})
      assert_equal(exp, print(string, opts: opts))
    end

    sig { params(string: String, opts: T::Hash[Symbol, T.untyped]).void }
    def assert_print_same(string, opts: {})
      assert_print_equal(string, string, opts: opts)
    end

    sig { params(exp: String, reader: IO, writer: IO, blk: T.proc.returns(T.untyped)).returns(T::Boolean) }
    def assert_log(exp, reader, writer, &blk)
      blk.call
      writer.close
      out = T.unsafe(reader).gets(nil)
      assert_equal(exp, out)
    end

    sig do
      params(
        level: Integer,
        color: T::Boolean,
        quiet: T::Boolean,
        logdev: T.any(String, IO, StringIO, NilClass)
      ).returns(Logger)
    end
    def logger(level: ::Logger::Severity::INFO, color: true, quiet: false, logdev: $stdout)
      Logger.new(level: level, color: color, quiet: quiet, logdev: logdev)
    end
  end
end

require "minitest/autorun"
