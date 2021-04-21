# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class RepoTest < Minitest::Test
    include TestHelper

    def test_repo_from_index
      index_json = <<~JSON
        {
          "foo": {
            "1.0.0": "foo@1.0.0.rbi"
          },
          "bar": {
            "1.0.0": "bar@1.0.0.rbi",
            "2.0.0": "bar@2.0.0.rbi"
          }
        }
      JSON

      repo = Repo.from_index(index_json)
      assert_equal("foo@1.0.0.rbi", repo.rbi_path("foo", "1.0.0"))
      assert_equal("bar@1.0.0.rbi", repo.rbi_path("bar", "1.0.0"))
      assert_equal("bar@2.0.0.rbi", repo.rbi_path("bar", "2.0.0"))
      assert_nil(repo.rbi_path("foo", "2.0.0"))
    end

    def test_repo_from_empty_index
      repo = Repo.from_index("{}")
      assert_empty(repo.gems)
    end

    def test_repo_from_empty_string
      assert_raises(JSON::ParserError) do
        Repo.from_index("")
      end
    end
  end
end
