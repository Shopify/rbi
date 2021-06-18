# typed: true
# frozen_string_literal: true

module RBI
  class CLI < ::Thor
    extend T::Sig
    include CLIHelper

    DEFAULT_PATH = "sorbet/rbi"

    class_option :color, type: :boolean, default: true
    class_option :quiet, type: :boolean, default: false, aliases: :q
    class_option :verbose, type: :boolean, default: false, aliases: :v
    class_option :mock_fetcher_file, type: :string

    desc "clean", "Remove all gem RBIs from local project"
    def clean
      context.clean
    end

    # TODO: Support triggering this command outside of root directory
    desc "init", "Initialize a project by retrieving all gem RBIs from central repository"
    def init
      context.init
    end

    desc "generate foo 1.0.0", "Generates RBI for a given gem. To use Sorbet in your project, use `rbi update` instead"
    option "source", type: :string, default: nil, desc: "Download gem from this source"
    option "git", type: :string, default: nil, desc: "Download gem from this git repo"
    option "branch", type: :string, default: nil, desc: "Install gem from this git branch"
    option "path", type: :string, default: nil, desc: "Install gem from this path"
    def generate(name, version = nil)
      source = options["source"]
      git = options["git"]
      path = options["path"]
      branch = options["branch"]
      logger = self.logger

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
        _, err, status = ctx.run("bundle exec tapioca generate")
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

    desc "update", "Update local gem RBIs"
    def update
      context.update
    end

    def self.exit_on_failure?
      true
    end
  end
end
