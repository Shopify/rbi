# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rbi"
require "minitest/test"
require "spoom/test_helpers/project"

module RBI
  module TestHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Minitest::Test

    TEST_PROJECTS_PATH = "/tmp/rbi/tests"

    sig { params(name: String).returns(Spoom::TestHelpers::Project) }
    def stub_project(name)
      StubProject.new("#{TEST_PROJECTS_PATH}/#{name}")
    end

    sig { params(exp: String, out: String).void }
    def assert_log(exp, out)
      assert_equal(exp, "#{out.rstrip}\n")
    end
  end

  class StubProject < Spoom::TestHelpers::Project
    extend T::Sig

    sig { params(cmd: String, args: String).returns([T.nilable(String), T.nilable(String), T::Boolean]) }
    def exec(cmd, *args)
      opts = {}
      opts[:chdir] = path
      out, err, status = Open3.capture3([cmd, *args].join(" "), opts)
      [out, err, status.success?]
    end

    sig { params(args: String).returns([T.nilable(String), T.nilable(String), T::Boolean]) }
    def rbi(*args)
      T.unsafe(self).exec("#{rbi_path}/exe/rbi", *args)
    end

    sig { returns(String) }
    def rbi_path
      path = ::File.dirname(__FILE__)   # rbi/test/
      path = ::File.dirname(path)       # rbi/
      ::File.expand_path(path)
    end

  end
end

require "minitest/autorun"
