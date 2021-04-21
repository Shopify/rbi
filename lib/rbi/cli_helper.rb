# typed: strict
# frozen_string_literal: true

require "thor"

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { returns(Client) }
    def client
      Client.new(logger)
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? ::Logger::Severity::DEBUG : ::Logger::Severity::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end
  end
end
