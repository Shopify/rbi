# typed: strict
# frozen_string_literal: true

module RBI
  class GithubFetcher < Fetcher
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi"
    CENTRAL_REPO_PATH = "central_repo"

    class FetchError < StandardError
      extend T::Sig

      sig { params(repo: String, cause: String).returns(String) }
      def self.error_string(repo, cause)
        <<~HELP
          Can't fetch RBI content from #{repo}

          It looks like we can't access #{repo} repo (#{cause}).

          Are you trying to access a private repository?
          If so, please specify your Github credentials in your ~/.netrc file.

          https://github.com/octokit/octokit.rb#using-a-netrc-file
        HELP
      end
    end

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
      github_file_content("#{CENTRAL_REPO_PATH}/#{path}")
    end

    private

    sig { returns(Octokit::Client) }
    def github_client
      @github_client ||= Octokit::Client.new
    end

    sig { params(name: String, version: String).returns(T.nilable(String)) }
    def rbi_path(name, version)
      index.fetch(name, nil)&.fetch(version, nil)
    end

    sig { returns(T::Hash[String, T::Hash[String, String]]) }
    def index
      @index ||= JSON.parse(index_string)
    end

    sig { returns(String) }
    def index_string
      @index_string ||= github_file_content("#{CENTRAL_REPO_PATH}/index.json")
    end

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      Base64.decode64(github_client.content(CENTRAL_REPO_SLUG, path: path).content)
    rescue Octokit::NotFound => e
      raise FetchError, FetchError.error_string(CENTRAL_REPO_SLUG, e.message)
    end
  end
end
