# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class GithubFetcherTest < Minitest::Test
      include TestHelper
      extend T::Sig

      def test_pull_rbi_without_auth
        fetcher = GithubFetcher.new(netrc: false)

        exception = assert_raises(RBI::GithubFetcher::FetchError) do
          fetcher.pull_rbi_content("foo", "1.0.0")
        end

        assert_log(<<~ERR, exception.message)
          Can't fetch RBI content from shopify/rbi-repo

          It looks like we can't access shopify/rbi-repo (GET https://api.github.com/repos/shopify/rbi-repo/contents/index.json: 404 - Not Found // See: https://docs.github.com/rest/reference/repos#get-repository-content).

          Are you trying to access a private repository?
          If so, please specify your Github credentials in your ~/.netrc file.

          https://github.com/Shopify/rbi#using-a-netrc-file
        ERR
      end
    end
  end
end
