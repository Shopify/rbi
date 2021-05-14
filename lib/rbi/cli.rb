# typed: true
# frozen_string_literal: true

require "thor"
require "bundler"

module RBI
  class CLI < ::Thor
    extend T::Sig
    include CLIHelper

    DEFAULT_PATH = "sorbet/rbi"

    class_option :color, type: :boolean, default: true
    class_option :quiet, type: :boolean, default: false, aliases: :q
    class_option :verbose, type: :boolean, default: false, aliases: :v

    # TODO: Support triggering this command outside of root directory
    desc "init", "Initialize a project by retrieving all gem RBIs from central repository"
    def init
      client = self.client
      client.init
    end

    desc "clean", "Remove all gem RBIs from local project"
    def clean
      client = self.client
      client.clean
    end

    desc "update", "Update local gem RBIs by pulling from central repository"
    def update
      client = self.client
      client.update
    end

    desc "generate [gem...]", "Generate RBIs from gems"
    def generate(*gems)
      if gems.empty?
        logger.error("Wrong number of arguments passed to `generate`. Please pass at least 1 gem")
        exit
      end

      entries = []
      requested_rbis = []

      gems.each do |gem|
        name, version = gem.split("@")
        if !name || !version
          @logger.error("Argument to `generate` is in the wrong format. Please pass in `gem_name@gem_version`.")
          exit
        end

        entries << "gem('#{name}', '#{version}')"
        requested_rbis << name
      end

      gemfile = <<~GEMFILE
        source "https://rubygems.org"
        source "https://pkgs.shopify.io/basic/gems/ruby"
        gem('tapioca')
      GEMFILE
      gemfile += entries.uniq.join("\n")

      client = self.client
      client.generate(gemfile, requested_rbis)
    end

    def self.exit_on_failure?
      true
    end
  end
end
