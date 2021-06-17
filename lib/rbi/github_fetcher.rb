# typed: strict
# frozen_string_literal: true

module RBI
  class GithubFetcher < Fetcher
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi"

    sig { void }
    def initialize
      super()
      @github_client = T.let(Octokit::Client.new, Octokit::Client)
      @index_string = T.let(nil, T.nilable(String))
      @repo = T.let(nil, T.nilable(Repo))
    end

    sig { override.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      path = repo.rbi_path(name, version)
      return nil unless path
      github_file_content("central_repo/#{path}")
    end

    private

    sig { returns(Repo) }
    def repo
      @repo ||= Repo.from_index(index_string)
    end

    sig { returns(String) }
    def index_string
      @index_string ||= github_file_content("central_repo/index.json")
    end

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      T.must(@github_client.file_content(CENTRAL_REPO_SLUG, path))
    end
  end
end
