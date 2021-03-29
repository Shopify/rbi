# typed: true
# frozen_string_literal: true

require "thor"

module RBI
  class CLI < ::Thor
    extend T::Sig
    include CLIHelper

    DEFAULT_PATH = "sorbet/rbi"

    class_option :color, type: :boolean, default: true
    class_option :quiet, type: :boolean, default: false, aliases: :q
    class_option :verbose, type: :boolean, default: false, aliases: :v

    def self.exit_on_failure?
      true
    end
  end
end
