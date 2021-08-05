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

    desc 'show', 'Show RBI content'
    # TODO format
    # TODO options
    def show(*paths)
      # files = expand_paths(paths)
      rbis = parse_files(paths)
      # logger = self.logger
      rbis.each do |file, rbi|
        # puts logger.colorize("\n# #{file}\n", :light_black)
        puts file
        puts rbi.string(
          # color: color?,
          # max_len: 100
        )
      end
    end

    # Utils

    def self.exit_on_failure?
      true
    end

    no_commands do
      def parse_files(files)
        # logger = self.logger

        # index = 0
        files.map do |file|
          # logger.debug("Parsing #{file} (#{index}/#{files.size})")
          # index += 1
          [file, T.must(RBI::Parser.parse_file(file))]
        end
      end
    end
  end
end
