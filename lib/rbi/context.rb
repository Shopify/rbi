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

    sig { params(path: String, logger: Logger).void }
    def initialize(path, logger: Logger.new)
      @path = path
      @logger = logger
    end

    # Actions

    sig { void }
    def clean
      path = gem_rbi_dir
      FileUtils.rm_rf(path)
      @logger.success("Clean `#{simplify_path(path)}` directory")
    end

    sig { params(client: Client).returns(T::Boolean) }
    def init(client)
      if has_local_rbis?
        @logger.error("Can't init while you RBI gems directory is not empty")
        @logger.hint("Run `rbi clean` to delete it")
        return false
      end
      gemfile_lock_parser.specs.each do |spec|
        client.pull_rbi(spec.name, spec.version.to_s)
      end
      true
    end

    sig { params(client: Client).void }
    def update(client)
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
        missing_specs << spec unless client.pull_rbi(name, version)
      end

      missing_specs = client.remove_application_spec(missing_specs)

      unless missing_specs.empty?
        exclude = parser.specs - missing_specs
        client.tapioca_generate(exclude: exclude)
      end

      @logger.success("Gem RBIs successfully updated")
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

    sig { returns(Pathname) }
    def root_pathname
      Pathname.new(@path)
    end

    sig { params(path: String).returns(String) }
    def simplify_path(path)
      path.delete_prefix("#{root_pathname}/")
    end
  end
end
