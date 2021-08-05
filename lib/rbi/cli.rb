# typed: true
# frozen_string_literal: true

require "thor"

module RBI
  class CLI < Thor
    extend T::Sig

    map T.unsafe(%w[--version -v] => :__print_version)

    desc "--version", "Show version"
    def __print_version
      puts "RBI v#{RBI::VERSION}"
    end

    # Utils

    def self.exit_on_failure?
      true
    end
  end
end
