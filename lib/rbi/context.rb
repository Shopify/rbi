# typed: strict
# frozen_string_literal: true

module RBI
  # The context (ie repo or project) where `rbi` is running
  class Context
    extend T::Sig

    IGNORED_GEMS = T.let(%w(sorbet sorbet-runtime sorbet-static), T::Array[String])

    sig { returns(String) }
    attr_reader :path

    sig { returns(Logger) }
    attr_reader :logger

    sig { params(path: String, logger: Logger, fetcher: Fetcher).void }
    def initialize(path, logger: Logger.new, fetcher: GithubFetcher.new)
      @path = path
      @logger = logger
      @fetcher = fetcher
    end

    # Actions

    sig { void }
    def clean
      path = gem_rbi_dir
      FileUtils.rm_rf(path)
      @logger.success("Clean `#{simplify_path(path)}` directory")
    end

    sig { void }
    def init
      if has_local_rbis?
        @logger.error("Can't init while you RBI gems directory is not empty")
        @logger.hint("Run `rbi clean` to delete it. Or use `rbi update` to update gem RBIs")
        exit(1)
      end

      update
    end

    sig { void }
    def update
      missing_specs = []
      parser = gemfile_lock_parser

      parser.specs.each do |spec|
        name = spec.name
        version = spec.version.to_s
        next if IGNORED_GEMS.include?(name)

        if has_local_rbi_for_gem_version?(name, version)
          next
        elsif has_local_rbi_for_gem?(name)
          remove_local_rbi_for_gem(name)
        end
        missing_specs << spec unless fetch_rbi(name, version)
      end

      missing_specs = remove_application_spec(missing_specs)

      unless missing_specs.empty?
        exclude = parser.specs - missing_specs
        generate_rbi(exclude: exclude)
      end

      @logger.success("Gem RBIs successfully updated")
    end

    sig { params(name: String, version: String, path: String).void }
    def push(name, version, path)
      @fetcher.push_rbi_content(name, version, path)
    end

    sig do
      params(
        name: String,
        version: T.nilable(String),
        source: T.nilable(String),
        git: T.nilable(String),
        branch: T.nilable(String),
        path: T.nilable(String)
      ).void
    end
    def generate(name, version: nil, source: nil, git: nil, branch: nil, path: nil)
      if [source, git, path].count { |x| !x.nil? } > 1
        logger.error(<<~ERR)
          You passed in too many options to `rbi generate`.
          Please pass only one of `--source`, `--git` and `--path`.
        ERR
        exit(1)
      end

      if branch && !git
        logger.error("Option `--branch` can only be used together with option `--git`")
        exit(1)
      end

      gem_string = String.new
      gem_string << "gem '#{name}'"
      gem_string << ", '#{version}'" if version
      gem_string << ", source: '#{source}'" if source
      gem_string << ", git: '#{git}'" if git
      gem_string << ", branch: '#{branch}'" if branch
      gem_string << ", path: '#{path}'" if path

      ctx = TMPDir.new("/tmp/rbi/generate/#{name}")
      ctx.gemfile(<<~GEMFILE)
        source "https://rubygems.org"

        #{gem_string}
        gem "tapioca"
      GEMFILE

      Bundler.with_unbundled_env do
        ctx.run("bundle config set --local path 'vendor/bundle'")
        _, err, status = ctx.run("bundle install")
        unless status
          logger.error(<<~ERR)
            If the gem you are specifying is not hosted on RubyGems please pass the correct flag to `rbi generate`.
            You can find all available flags by running `bundle exec rbi help generate`.
            \n#{err}
          ERR
          exit(1)
        end
        _, err, status = ctx.bundle_exec("tapioca generate")
        unless status
          logger.error("Unable to generate RBI: #{err}")
          exit(1)
        end
      end
      gem_rbi_path = "#{ctx.path}/sorbet/rbi/gems/#{name}@#{version}*.rbi"
      files = Dir[gem_rbi_path]
      if files.empty?
        logger.error("Unable to generate RBI: no file matching #{gem_rbi_path}")
        exit(1)
      end

      file_path = T.must(files.first)
      version_string = file_path.sub(/^.*@/, "").sub(/\.rbi$/, "")
      FileUtils.mv(file_path, ".")
      logger.success("Generated `#{name}@#{version_string}.rbi`")

      ctx.destroy
    end

    sig { params(rbi1: String, rbi2: String).returns([String, T::Array[Tapioca::RBI::Rewriters::Merge::Conflict]]) }
    def merge(rbi1, rbi2)
      tree1 = parse_file(rbi1)
      tree2 = parse_file(rbi2)

      merger = Tapioca::RBI::Rewriters::Merge.new(left_name: rbi1, right_name: rbi2)

      conflicts = []
      conflicts.concat(merger.merge(tree1))
      conflicts.concat(merger.merge(tree2))
      merged = merger.tree

      [merged.string, conflicts]
    end

    # Utils

    sig { returns(String) }
    def gem_rbi_dir
      (root_pathname / "sorbet/rbi/gems").to_s
    end

    sig { returns(String) }
    def gemfile_lock_path
      (root_pathname / "Gemfile.lock").to_s
    end

    sig { returns(Bundler::LockfileParser) }
    def gemfile_lock_parser
      file = Bundler.read_file(gemfile_lock_path)
      Bundler::LockfileParser.new(file)
    end

    sig { params(name: String, version: String).returns(T::Boolean) }
    def has_local_rbi_for_gem_version?(name, version)
      File.file?("#{gem_rbi_dir}/#{name}@#{version}.rbi")
    end

    sig { params(name: String).returns(T::Boolean) }
    def has_local_rbi_for_gem?(name)
      !Dir.glob("#{gem_rbi_dir}/#{name}@*.rbi").empty?
    end

    sig { returns(T::Boolean) }
    def has_local_rbis?
      !Dir.glob("#{gem_rbi_dir}/*.rbi").empty?
    end

    sig { params(name: String).void }
    def remove_local_rbi_for_gem(name)
      Dir.glob("#{gem_rbi_dir}/#{name}@*.rbi").each do |path|
        FileUtils.rm_rf(path)
      end
    end

    private

    sig { params(name: String, version: String).returns(T::Boolean) }
    def fetch_rbi(name, version)
      content = @fetcher.pull_rbi_content(name, version)
      return false unless content

      dir = gem_rbi_dir
      FileUtils.mkdir_p(dir)
      File.write("#{dir}/#{name}@#{version}.rbi", content)
      @logger.success("Pulled `#{name}@#{version}.rbi` from central repository")

      true
    rescue GithubFetcher::FetchError => e
      @logger.error(e.message)
      exit(1)
    end

    sig { params(exclude: T::Array[Bundler::LazySpecification]).void }
    def generate_rbi(exclude:)
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

    sig { params(specs: T::Array[Bundler::LazySpecification]).returns(T::Array[Bundler::LazySpecification]) }
    def remove_application_spec(specs)
      return specs if specs.empty?
      application_directory = File.expand_path(Bundler.root)
      specs.reject do |spec|
        spec.source.class == Bundler::Source::Path && File.expand_path(spec.source.path) == application_directory
      end
    end

    sig { returns(Pathname) }
    def root_pathname
      Pathname.new(@path)
    end

    sig { params(path: String).returns(String) }
    def simplify_path(path)
      path.delete_prefix("#{root_pathname}/")
    end

    sig { params(path: String).void }
    def check_file_exists(path)
      unless File.file?(path)
        logger.error("Can't read file `#{path}`.")
        exit(1)
      end
    end

    sig { params(path: String).returns(Tapioca::RBI::Tree) }
    def parse_file(path)
      check_file_exists(path)
      Tapioca::RBI::Parser.parse_file(path)
    rescue Tapioca::RBI::Parser::Error => e
      logger.error("Parse error in `#{path}`: #{e.message}.")
      exit(1)
    end
  end
end
