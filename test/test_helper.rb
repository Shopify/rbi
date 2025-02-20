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

module TestHelper
  extend T::Sig

  private

  #: (String rbs_string) -> RBI::Tree
  def parse_rbi(rbs_string)
    RBI::Parser.parse_string(rbs_string)
  end
end
