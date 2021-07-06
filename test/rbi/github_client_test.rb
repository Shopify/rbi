# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class GithubClientTest < Minitest::Test
      include TestHelper
      extend T::Sig

      def test_pull_rbi_without_auth
        client = GithubClient.new(netrc: false)

        exception = assert_raises(RBI::GithubClient::FetchError) do
          client.pull_rbi_content("foo", "1.0.0")
        end

        assert_log(<<~ERR, exception.message)
          Can't fetch RBI content from shopify/rbi-repo

          It looks like we can't access shopify/rbi-repo (GET https://api.github.com/repos/shopify/rbi-repo/contents/index.json: 404 - Not Found // See: https://docs.github.com/rest/reference/repos#get-repository-content).

          Are you trying to access a private repository?
          If so, please specify your Github credentials in your ~/.netrc file.

          https://github.com/Shopify/rbi#using-a-netrc-file
        ERR
      end

      def test_pull_rbi_from_public_repo
        client = GithubClient.new(netrc: false, central_repo_slug: "Shopify/rbi-repo-test")
        rbi = client.pull_rbi_content("foo", "1.0.0")

        assert_equal(<<~RBI, rbi)
          # typed: true

          module Foo
            FOO = 42
          end
        RBI
      end
    end
  end
end
