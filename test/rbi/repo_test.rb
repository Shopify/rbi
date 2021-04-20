# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class RepoTest < Minitest::Test
    include TestHelper

    def setup
      @project = project("repo_test")
    end

    def teardown
      @project.destroy
    end

    # def test
    #   @project.write("", <<~RB)
    #   RB

    #   expected = <<~OUT
    #   OUT

    #   out, status = @project.run("")
    #   assert(status)
    #   assert_equal(expected, out)
    # end
  end
end
