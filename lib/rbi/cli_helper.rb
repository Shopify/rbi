# typed: strict
# frozen_string_literal: true

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { returns(Context) }
    def context
      Context.new(".", logger: logger) # TODO: pass `path` as an option
    end

    sig { params(mock_github_client: T::Boolean).returns(Fetcher) }
    def fetcher(mock_github_client = false)
      return Fetcher.new(github_client: RBI::MockGithubClient.new) if mock_github_client
      Fetcher.new
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end
  end
end
