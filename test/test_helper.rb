# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

# Tag all test classes as covering all subjects.
# Just a WIP state, not the final solution.
#
# This is a very primitive but also very effective initial setup.
class MiniTest::Test
  cover "RBI*"
end

require "rbi"
require "minitest/test"
require "minitest/autorun"
