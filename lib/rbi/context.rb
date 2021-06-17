# typed: strict
# frozen_string_literal: true

module RBI
  # The context (ie repo or project) where `rbi` is running
  class Context
    extend T::Sig

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

    # Utils

    sig { returns(String) }
    def gem_rbi_dir
      (root_pathname / "sorbet/rbi/gems").to_s
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
