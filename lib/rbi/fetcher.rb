# typed: strict
# frozen_string_literal: true

module RBI
  class Fetcher
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi"

    sig { params(github_client: GithubClient).void }
    def initialize(github_client: Octokit::Client.new(netrc: true))
      @github_client = github_client
      index = github_file_content("central_repo/index.json")
      @repo = T.let(Repo.from_index(index), Repo)
    end

    sig { params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      path = @repo.rbi_path(name, version)
      return nil unless path
      github_file_content("central_repo/#{path}")
    end

    private

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      T.must(@github_client.file_content(CENTRAL_REPO_SLUG, path))
    end
  end
end
