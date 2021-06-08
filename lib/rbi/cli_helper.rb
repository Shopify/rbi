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

    sig { params(input_string: String, cloudsmith_source: T::Boolean).void }
    def generate_rbi(input_string, cloudsmith_source)
      logger = self.logger
      split = input_string.split("@")
      unless split.size == 2
        logger.error("Argument to `generate` is in the wrong format. Please pass in `gem_name@full_version_number`.")
        exit
      end
      name, version = split

      ctx = Context.new("/tmp/rbi/generate/#{name}")
      gem_string =
        if cloudsmith_source
          "gem '#{name}', '#{version}', source: 'https://pkgs.shopify.io/basic/gems/ruby'"
        else
          "gem '#{name}', '#{version}'"
        end

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
            If the gem you are specifying is hosted on cloudsmith please pass `--cloudsmith-source` flag to `rbi generate`.
            Unable to install gem: #{err}
          ERR
          exit
        end
        _, err, status = ctx.run("bundle exec tapioca generate")
        unless status
          logger.error("Unable to generate RBI: #{err}.")
          exit
        end
      end
      FileUtils.mv("#{ctx.path}/sorbet/rbi/gems/#{name}@#{version}.rbi", ".")
      logger.success("Generated `#{name}@#{version}.rbi`")

      ctx.destroy
    end
  end
end
