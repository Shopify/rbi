# typed: strict
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rbi"
require "minitest/test"
require "minitest/autorun"
require "minitest/reporters"

unless ENV["RM_INFO"]
  Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new(color: true))
end
