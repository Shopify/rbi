# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rbi"
require "rbi/test_helpers/context"
require "minitest/test"

module RBI
  module TestHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Minitest::Test

    TEST_PROJECTS_PATH = "/tmp/rbi/tests"

    sig { params(name: String).returns(Context) }
    def project(name)
      Context.new("#{TEST_PROJECTS_PATH}/#{name}")
    end

    sig { params(level: Integer, quiet: T::Boolean, color: T::Boolean).returns([Logger, StringIO]) }
    def logger(level: Logger::INFO, quiet: false, color: false)
      out = StringIO.new
      [Logger.new(level: level, quiet: quiet, color: color, out: out), out]
    end

    sig { params(exp: String, out: String).void }
    def assert_log(exp, out)
      assert_equal(exp, "#{out.rstrip}\n")
    end
  end
end

require "minitest/autorun"
