# typed: strict
# frozen_string_literal: true

module RBI
  class Client
    extend T::Sig

    sig { params(logger: Logger, github_client: T.nilable(GithubClient), project_path: String).void }
    def initialize(logger, github_client: nil, project_path: ".")
      @logger = logger
    end

    sig { params(exclude: T::Array[Bundler::LazySpecification]).void }
    def tapioca_generate(exclude:)
      @logger.info("Generating RBIs that were missing in the central repository using tapioca")
      spec_names = exclude.map(&:name)
      exclude_option = exclude.empty? ? "" : "--exclude #{spec_names.join(" ")}"

      out, err, status = Open3.capture3("bundle exec tapioca generate #{exclude_option}")
      unless status.success?
        @logger.error("Unable to generate RBI: #{err}")
        exit(1)
      end

      @logger.debug("#{out}\n")
    end
  end
end
