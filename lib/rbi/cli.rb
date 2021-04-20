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

    desc "init", "Initialize a project by retrieving all gem RBIs from central repository"
    def init
      # Read gemfile.lock and retrieve gems
      # TODO: Support triggering this command outside of root directory
      file = Bundler.read_file("Gemfile.lock")
      parser = Bundler::LockfileParser.new(file)
      parser.specs.each do |spec|
        version = spec.version.to_s
        name = spec.name
        pull_rbi(name, version)
      end
    end

    def self.exit_on_failure?
      true
    end
  end
end
