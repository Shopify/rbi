# typed: strict
# frozen_string_literal: true

module RBI
  class GithubFetcher < Fetcher
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi-repo"

    class FetchError < StandardError
      extend T::Sig

      sig { params(repo: String, cause: String).returns(String) }
      def self.error_string(repo, cause)
        <<~HELP
          Can't fetch RBI content from #{repo}

          It looks like we can't access #{repo} (#{cause}).

          Are you trying to access a private repository?
          If so, please specify your Github credentials in your ~/.netrc file.

          https://github.com/Shopify/rbi#using-a-netrc-file
        HELP
      end
    end

    sig { params(netrc: T::Boolean, netrc_file: T.nilable(String), central_repo_slug: T.nilable(String)).void }
    def initialize(netrc: true, netrc_file: nil, central_repo_slug: nil)
      super()
      @netrc = netrc
      @netrc_file = netrc_file
      @central_repo_slug = T.let(central_repo_slug || CENTRAL_REPO_SLUG, String)
      @github_client = T.let(nil, T.nilable(Octokit::Client))
      @index_string = T.let(nil, T.nilable(String))
      @index = T.let(nil, T.nilable(T::Hash[String, T::Hash[String, String]]))
    end

    sig { override.params(name: String, version: String).returns(T.nilable(String)) }
    def pull_rbi_content(name, version)
      path = rbi_path(name, version)
      return nil unless path
      github_file_content(path)
    end

    private

    sig { returns(Octokit::Client) }
    def github_client
      @github_client ||= Octokit::Client.new(netrc: @netrc, netrc_file: netrc_file)
    end

    sig { returns(String) }
    def netrc_file
      @netrc_file || ENV["RBI_NETRC"] || ENV["OCTOKIT_NETRC"] || ENV["NETRC"] || File.join(ENV["HOME"], ".netrc")
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
      @index_string ||= github_file_content("index.json")
    end

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      Base64.decode64(github_client.content(@central_repo_slug, path: path).content)
    rescue Octokit::NotFound => e
      raise FetchError, FetchError.error_string(@central_repo_slug, e.message)
    end
  end
end
