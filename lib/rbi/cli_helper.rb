# typed: strict
# frozen_string_literal: true

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { returns(Context) }
    def context
      Context.new(".", logger: logger, fetcher: fetcher) # TODO: pass `path` as an option
    end

    sig { returns(Fetcher) }
    def fetcher
      mock_file = options[:mock_fetcher_file]
      return MockFetcher.from_file(mock_file) if mock_file

      GithubFetcher.new(
        netrc: options[:netrc],
        netrc_file: options[:netrc_file],
        central_repo_slug: options[:central_repo_slug]
      )
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end
  end
end
