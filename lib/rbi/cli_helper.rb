# typed: strict
# frozen_string_literal: true

require "thor"

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    GEM_RBI_DIRECTORY = "sorbet/rbi/gems"
    CENTRAL_REPO_PATH = T.let("#{__dir__}/../../central_repo", String)

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? ::Logger::Severity::DEBUG : ::Logger::Severity::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end

    sig { params(name: String, version: String).returns(T::Boolean) }
    def pull_rbi(name, version)
      repo = self.repo
      rbi_path = repo.retrieve_rbi(name, version)
      unless rbi_path
        logger.error("The RBI for `#{name}@#{version}` gem doesn't exist in the central repository\n" \
                     "Run `rbi generate #{name}@#{version}` to generate it.\n")
        return false
      end

      # TODO: Download rbi_path from Github

      # Move them to the application's sorbet/rbi/
      FileUtils.mkdir_p(GEM_RBI_DIRECTORY)
      FileUtils.cp(rbi_path, GEM_RBI_DIRECTORY)

      true
    end

    sig { returns(Repo) }
    def repo
      Repo.from_index_file(CENTRAL_REPO_PATH)
    end
  end
end
