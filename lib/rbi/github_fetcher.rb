# typed: strict
# frozen_string_literal: true

module RBI
  class GithubFetcher < Fetcher
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi"

    sig { void }
    def initialize
      super()
      @github_client = T.let(nil, T.nilable(Octokit::Client))
      @index_string = T.let(nil, T.nilable(String))
      @index = T.let(nil, T.nilable(T::Hash[String, T::Hash[String, String]]))
    end

    sig { override.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      path = rbi_path(name, version)
      return nil unless path
      github_file_content("central_repo/#{path}")
    end

    private

    sig { returns(Octokit::Client) }
    def github_client
      @github_client ||= Octokit::Client.new
    end

    sig { params(name: String, version: String).returns(T.nilable(String)) }
    def rbi_path(name, version)
      index&.fetch(name, nil)&.fetch(version, nil)
    end

    sig { returns(String) }
    def index
      @index ||= JSON.parse(index_string)
    end

    sig { returns(String) }
    def index_string
      @index_string ||= github_file_content("central_repo/index.json")
    end

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      Base64.decode64(github_client.content(CENTRAL_REPO_SLUG, path: path).content)
    end
  end
end
