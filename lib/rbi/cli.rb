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

    def self.exit_on_failure?
      true
    end
  end
end
