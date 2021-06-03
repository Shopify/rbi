# typed: strict
# frozen_string_literal: true

module RBI
  class Client
    extend T::Sig

    CENTRAL_REPO_SLUG = "shopify/rbi"
    GEM_RBI_DIRECTORY = "sorbet/rbi/gems"
    IGNORED_GEMS      = T.let(%w(sorbet sorbet-runtime sorbet-static), T::Array[String])

    sig { params(logger: Logger, github_client: T.nilable(GithubClient), project_path: String).void }
    def initialize(logger, github_client: nil, project_path: ".")
      @logger = logger
      @project_path = project_path

      @github_client = T.let(github_client || Octokit::Client.new(
        access_token: github_token,
        auto_paginate: true,
        per_page: 100
      ), GithubClient)

      index = github_file_content("central_repo/index.json")
      @repo = T.let(Repo.from_index(index), Repo)
      @parser = T.let(nil, T.nilable(Bundler::LockfileParser))
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
      missing_specs = []

      parser.specs.each do |spec|
        name = spec.name
        version = spec.version.to_s
        next if IGNORED_GEMS.include?(name)

        if has_local_rbi_for_gem_version?(name, version)
          next
        elsif has_local_rbi_for_gem?(name)
          remove_local_rbi_for_gem(name)
        end
        missing_specs << spec unless pull_rbi(name, version)
      end

      missing_specs = remove_application_spec(missing_specs)

      unless missing_specs.empty?
        exclude = parser.specs - missing_specs
        tapioca_generate(exclude: exclude)
      end

      @logger.success("Gem RBIs successfully updated.")
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
      @logger.success("Pulled `#{name}@#{version}.rbi` from central repository")

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
      @parser ||= gemfile_lock_parser
    end

    sig { params(specs: T::Array[Bundler::LazySpecification]).returns(T::Array[Bundler::LazySpecification]) }
    def remove_application_spec(specs)
      return specs if specs.empty?
      application_directory = File.expand_path(Bundler.root)
      specs.reject do |spec|
        spec.source.class == Bundler::Source::Path && File.expand_path(spec.source.path) == application_directory
      end
    end

    sig { params(exclude: T::Array[Bundler::LazySpecification]).void }
    def tapioca_generate(exclude:)
      @logger.info("Generating RBIs that were missing in the central repository using tapioca.")
      spec_names = exclude.map(&:name)
      exclude_option = exclude.empty? ? "" : "--exclude #{spec_names.join(" ")}"

      out, err, status = Open3.capture3("bundle exec tapioca generate #{exclude_option}")
      unless status.success?
        @logger.error("Unable to generate RBI: #{err}.")
        exit
      end

      @logger.debug(out)
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

    sig { returns(Bundler::LockfileParser) }
    def gemfile_lock_parser
      file = Bundler.read_file("#{@project_path}/Gemfile.lock")
      Bundler::LockfileParser.new(file)
    end
  end
end
