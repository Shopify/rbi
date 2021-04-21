# typed: strict
# frozen_string_literal: true

module RBI
  class Client
    extend T::Sig

    CENTRAL_REPO_PATH = T.let("#{__dir__}/../../central_repo", String)
    CENTRAL_REPO_SLUG = "shopify/rbi"
    GEM_RBI_DIRECTORY = "sorbet/rbi"

    def initialize(logger)
      @logger = logger
    end

    def init
      file = Bundler.read_file("Gemfile.lock")
      parser = Bundler::LockfileParser.new(file)
      parser.specs.each do |spec|
        version = spec.version.to_s
        name = spec.name
        pull_rbi(name, version)
      end
    end

    private

    sig { params(name: String, version: String).returns(T::Boolean) }
    def pull_rbi(name, version)
      path = repo.rbi_path(name, version)
      unless path
        @logger.error("The RBI for `#{name}@#{version}` gem doesn't exist in the central repository\n" \
                      "Run `rbi generate #{name}@#{version}` to generate it.\n")
        return false
      end

      content = github_client.content(CENTRAL_REPO_SLUG, path: "central_repo/#{path}").content
      str = Base64.decode64(content)

      FileUtils.mkdir_p("#{GEM_RBI_DIRECTORY}/gems")
      File.write("#{GEM_RBI_DIRECTORY}/#{path}", str)

      true
    end

    sig { returns(Repo) }
    def repo
      Repo.from_index_file(CENTRAL_REPO_PATH)
    end

    def github_client
      @github_client ||= Octokit::Client.new(
        access_token: github_token,
        auto_paginate: true,
        per_page: 100
      )
    end

    def github_token
      token = load_token("github.token", "GITHUB_TOKEN")
      if token.nil? || token == ''
        logger.error("Please set a Github Token so rbi can access the central repository" \
                     " by setting the environment variable `GITHUB_TOKEN`" \
                     " or creating a `github.token` file.")
        Kernel.exit(1)
      end
      token
    end

    def load_token(file, env)
      if File.file?(file)
        return File.read(file).strip
      elsif ENV.key?(env)
        return ENV[env]&.strip
      end
      nil
    end
  end
end
