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
    option "mock-github-client", type: :boolean, default: false
    def init
      client = self.client(options["mock-github-client"])
      client.init
    end

    desc "clean", "Remove all gem RBIs from local project"
    def clean
      client = self.client
      client.clean
    end

    desc "update", "Update local gem RBIs"
    option "mock-github-client", type: :boolean, default: false
    def update
      client = self.client(options["mock-github-client"])
      client.update
    end

    desc "generate foo@1.0.0", "Generates RBI for a given gem. To use Sorbet in your project, use `rbi update` instead."
    option "cloudsmith-source",
      type: :boolean,
      default: false,
      desc: "Gem should be downloaded from cloudsmith instead of rubygems"
    def generate(gem)
      generate_rbi(gem, options["cloudsmith-source"])
    end

    def self.exit_on_failure?
      true
    end
  end
end
