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
      netrc = options[:netrc]
      netrc_file = options[:netrc_file]
      central_repo_slug = options[:central_repo_slug]
      mock_file = options[:mock_fetcher_file]

      if mock_file
        if netrc || netrc_file || central_repo_slug
          logger.error("Option `--mock-fetcher-file` can't be used with options `--netrc`, " \
                        "`--netrc-file` and `--central-repo-slug`")
          exit(1)
        end

        return MockFetcher.from_file(mock_file)
      end

      if netrc_file && !netrc
        logger.error("Option `--netrc-file` can only be used with option `--netrc`")
        exit(1)
      end

      GithubFetcher.new(netrc: netrc, netrc_file: netrc_file, central_repo_slug: central_repo_slug)
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end
  end
end
