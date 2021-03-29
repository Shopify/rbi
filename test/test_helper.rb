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

    sig { params(name: String).returns(TestHelpers::Project) }
    def project(name)
      TestHelpers::Project.new("#{TEST_PROJECTS_PATH}/#{name}")
    end
  end
end

require "minitest/autorun"
