# typed: strict
# frozen_string_literal: true

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { returns(Context) }
    def context
      Context.new(".", logger: logger) # TODO: pass `path` as an option
    end

    sig { params(mock_github_client: T::Boolean).returns(Fetcher) }
    def fetcher(mock_github_client = false)
      return Fetcher.new(github_client: RBI::MockGithubClient.new) if mock_github_client
      Fetcher.new
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
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
    def generate_rbi(name, version: nil, source: nil, git: nil, branch: nil, path: nil)
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

      ctx = MockContext.new("/tmp/rbi/generate/#{name}")
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
  end
end
