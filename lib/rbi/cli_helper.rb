# typed: strict
# frozen_string_literal: true

require "thor"

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { params(mock_github_client: T::Boolean).returns(Client) }
    def client(mock_github_client = false)
      return Client.new(logger, github_client: RBI::MockGithubClient.new) if mock_github_client

      Client.new(logger)
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end
  end
end
