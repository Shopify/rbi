# typed: strict
# frozen_string_literal: true

module RBI
  class Client
    extend T::Sig

    CENTRAL_REPO_PATH = T.let("#{__dir__}/../../central_repo", String)
    CENTRAL_REPO_SLUG = "shopify/rbi"
    GEM_RBI_DIRECTORY = "sorbet/rbi"

    sig { params(logger: Logger).void }
    def initialize(logger)
      @logger = logger
      @github_client = T.let(Octokit::Client.new(
        access_token: github_token,
        auto_paginate: true,
        per_page: 100
      ), Octokit::Client)

      index = github_file_content("central_repo/index.json")
      @repo = T.let(Repo.from_index(index), Repo)
    end

    sig { void }
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
      path = @repo.rbi_path(name, version)
      unless path
        @logger.error("The RBI for `#{name}@#{version}` gem doesn't exist in the central repository\n" \
                      "Run `rbi generate #{name}@#{version}` to generate it.\n")
        return false
      end

      str = github_file_content("central_repo/#{path}")

      FileUtils.mkdir_p("#{GEM_RBI_DIRECTORY}/gems")
      File.write("#{GEM_RBI_DIRECTORY}/#{path}", str)

      true
    end

    sig { returns(String) }
    def github_token
      token = load_token("github.token", "GITHUB_TOKEN")
      if token.nil? || token == ""
        @logger.error("Please set a Github Token so rbi can access the central repository" \
                     " by setting the environment variable `GITHUB_TOKEN`" \
                     " or creating a `github.token` file.")
        Kernel.exit(1)
      end
      token
    end

    sig { params(file: String, env: String).returns(T.nilable(String)) }
    def load_token(file, env)
      if File.file?(file)
        return File.read(file).strip
      elsif ENV.key?(env)
        return ENV[env]&.strip
      end
      nil
    end

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      content = @github_client.content(CENTRAL_REPO_SLUG, path: path).content
      Base64.decode64(content)
    end
  end
end
