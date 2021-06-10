# typed: strict
# frozen_string_literal: true

require "thor"

module RBI
  module CLIHelper
    extend T::Sig
    extend T::Helpers

    requires_ancestor Thor

    sig { params(mock_github_client: T::Boolean).returns(Client) }
    def client(mock_github_client = false)
      return Client.new(logger, github_client: RBI::MockGithubClient.new) if mock_github_client

      Client.new(logger)
    end

    sig { returns(Logger) }
    def logger
      level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      Logger.new(level: level, color: options[:color], quiet: options[:quiet])
    end

    sig do
      params(
        name: String,
        version: String,
        source: T.nilable(String),
        git: T.nilable(String),
        path: T.nilable(String)
      ).void
    end
    def generate_rbi(name, version, source: nil, git: nil, path: nil)
      logger = self.logger

      arr = [source, git, path]
      num_options = arr.count { |x| !x.nil? }
      if num_options > 1
        logger.error(<<~ERR)
          You passed in too many options to `rbi generate`.
          Please pass only one of `--source`, `--git` and `--path`.
        ERR
        exit(1)
      end

      gem_string = if source
        "gem '#{name}', '#{version}', source: '#{source}'"
      elsif git
        "gem '#{name}', '#{version}', git: '#{git}'" # TODO: Support passing a specific branch
      elsif path
        "gem '#{name}', '#{version}', path: '#{path}'"
      else
        "gem '#{name}', '#{version}'"
      end

      ctx = Context.new("/tmp/rbi/generate/#{name}")
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
      begin
        gem_rbi_path = "#{ctx.path}/sorbet/rbi/gems"
        if git
          file_path = Dir["#{gem_rbi_path}/#{name}@#{version}-*.rbi"]
          FileUtils.mv(file_path, ".")
          logger.success("Generated RBI for `#{name}@#{version}`")
        else
          FileUtils.mv("#{gem_rbi_path}/#{name}@#{version}.rbi", ".")
          logger.success("Generated `#{name}@#{version}.rbi`")
        end
      rescue Errno::ENOENT
        logger.error(<<~ERR)
          Unable to move gem RBI to target directory. Generated RBI must have a different version number than what you specifified.
          Ensure version number to `rbi generate` command matches the version number retrieved from your specific source.
        ERR
      end

      ctx.destroy
    end
  end
end
