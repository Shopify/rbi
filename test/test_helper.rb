# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rbi"
require "rbi/test_helpers/project"
require "minitest/test"

module RBI
  module TestHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Minitest::Test

    TEST_PROJECTS_PATH = "/tmp/rbi/tests"

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

    sig { params(name: String).returns(TestHelpers::Project) }
    def project(name)
      project = TestHelpers::Project.new("#{TEST_PROJECTS_PATH}/#{name}")
      project.gemfile(gemfile)
      project
    end

    sig { returns(String) }
    def gemfile
      <<~GEM
        gem("rbi", path: "#{rbi_path}")
      GEM
    end

    sig { returns(String) }
    def rbi_path
      path = File.dirname(__FILE__)   # rbi/test/rbi/
      path = File.dirname(path)       # rbi/test/
      path = File.dirname(path)       # rbi/
      File.expand_path(path)
    end
  end
end

require "minitest/autorun"
