# typed: strict
# frozen_string_literal: true

module RBI
  class Client
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi"
    GEM_RBI_DIRECTORY = "sorbet/rbi/gems"

    sig { params(logger: Logger, github_client: T.nilable(GithubClient), project_path: String).void }
    def initialize(logger, github_client: nil, project_path: ".")
      @logger = logger
      @project_path = project_path
      @lockfile = T.let("#{@project_path}/Gemfile.lock", String)

      @github_client = T.let(github_client || Octokit::Client.new(
        access_token: github_token,
        auto_paginate: true,
        per_page: 100
      ), GithubClient)

      index = github_file_content("central_repo/index.json")
      @repo = T.let(Repo.from_index(index), Repo)
    end

    sig { void }
    def clean
      FileUtils.rm_rf("#{@project_path}/#{GEM_RBI_DIRECTORY}")
      @logger.success("Clean `#{@project_path}/#{GEM_RBI_DIRECTORY}` directory.")
    end

    sig { returns(T::Boolean) }
    def init
      unless Dir.glob("#{@project_path}/#{GEM_RBI_DIRECTORY}/*.rbi").empty?
        @logger.error("Can't init while you RBI gems directory is not empty.")
        @logger.hint("Run `rbi clean` to delete it.")
        return false
      end

      parser.specs.each do |spec|
        pull_rbi(spec.name, spec.version.to_s)
      end
      true
    end

    sig { void }
    def update
      missing_rbis = []

      parser.specs.each do |spec|
        name = spec.name
        version = spec.version.to_s
        if has_local_rbi_for_gem_version?(name, version)
          next
        elsif has_local_rbi_for_gem?(name)
          remove_local_rbi_for_gem(name)
        end
        missing_rbis << [name, version] unless pull_rbi(name, version)
      end
      unless missing_rbis.empty?
        gemfile = <<~GEMFILE
          source "https://rubygems.org"
          source "https://pkgs.shopify.io/basic/gems/ruby"
          gem('tapioca')
        GEMFILE

        entries = []
        missing_rbis.each do |rbi|
          name = rbi[0]
          version = rbi[1]
          # TODO: Remove conditionals when "rbi" is published. Workaround for app itself being a spec
          entries << "gem('#{name}', '#{version}')" unless name == "rbi" || name == "test"
        end
        gemfile += entries.uniq.join("\n")

        generate(gemfile, missing_rbis.map(&:first))
      end

      @logger.success("Gem RBIs successfully updated.")
    end

    sig { params(gemfile: String, requested_rbis: T::Array[String]).void }
    def generate(gemfile, requested_rbis)
      ctx = Context.new("/tmp/rbi/generate")
      ctx.sorbet_config(".")
      ctx.gemfile(gemfile)

      Bundler.with_unbundled_env do
        ctx.run("bundle config set --local path 'vendor/bundle'")
        _, err, status = ctx.run("bundle", "install")
        unless status
          @logger.error("Unable to generate RBI: #{err}")
          ctx.destroy
          exit
        end

        # TODO: "--only" option to not generate subdependency RBIs?
        _, err, status = ctx.run("bundle", "exec", "tapioca", "generate")
        unless status
          @logger.error("Unable to generate RBI: #{err}")
          ctx.destroy
          exit
        end
      end

      out, err, status = ctx.run("ls sorbet/rbi/gems")
      unless status
        @logger.error("Unable to generate RBI: #{err}")
        ctx.destroy
        exit
      end

      generated_rbis = T.must(out).split
      generated_rbis.each do |filename|
        name = filename.split("@").first
        next unless requested_rbis.include?(name)
        gem_rbi_path = ctx.absolute_path("sorbet/rbi/gems/#{filename}")
        FileUtils.cp(gem_rbi_path, "#{@project_path}/#{GEM_RBI_DIRECTORY}/")
        @logger.success("Generated #{filename}")
      end

      ctx.destroy
    end

    sig { params(name: String, version: String).returns(T::Boolean) }
    def pull_rbi(name, version)
      path = @repo.rbi_path(name, version)
      unless path
        return false
      end

      str = github_file_content("central_repo/#{path}")

      dir = "#{@project_path}/#{GEM_RBI_DIRECTORY}"
      FileUtils.mkdir_p(dir)
      File.write("#{dir}/#{path}", str)
      @logger.success("Pulled #{name}@#{version}.rbi from central repository")

      true
    end

    sig { params(name: String, version: String).returns(T::Boolean) }
    def has_local_rbi_for_gem_version?(name, version)
      File.file?("#{@project_path}/#{GEM_RBI_DIRECTORY}/#{name}@#{version}.rbi")
    end

    sig { params(name: String).returns(T::Boolean) }
    def has_local_rbi_for_gem?(name)
      !Dir.glob("#{@project_path}/#{GEM_RBI_DIRECTORY}/#{name}@*.rbi").empty?
    end

    sig { params(name: String).void }
    def remove_local_rbi_for_gem(name)
      Dir.glob("#{@project_path}/#{GEM_RBI_DIRECTORY}/#{name}@*.rbi").each do |path|
        FileUtils.rm_rf(path)
      end
    end

    private

    sig { returns(Bundler::LockfileParser) }
    def parser
      @parser = T.let(@parser, T.nilable(Bundler::LockfileParser))
      @parser ||= begin
        file = Bundler.read_file(@lockfile)
        Bundler::LockfileParser.new(file)
      end
    end

    sig { returns(String) }
    def github_token
      token = load_token("/opt/dev/var/private/git_credential_store", "GITHUB_TOKEN")
      if token.nil? || token == ""
        @logger.error("Please set a Github Token so rbi can access the central repository" \
                      " by setting the environment variable `GITHUB_TOKEN`" \
                      " or creating a `github.token` file.")
        exit(1)
      end
      token
    end

    sig { params(file: String, env: String).returns(T.nilable(String)) }
    def load_token(file, env)
      if File.file?(file)
        content = File.read(file).strip
        return content.split(":").last&.split("@")&.first
      elsif ENV.key?(env)
        return ENV[env]&.strip
      end

      nil
    end

    sig { params(path: String).returns(String) }
    def github_file_content(path)
      T.must(@github_client.file_content(CENTRAL_REPO_SLUG, path))
    end
  end
end
