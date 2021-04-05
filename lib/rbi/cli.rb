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

    desc "validate", "Validate RBI content"
    def validate(*paths)
      T.unsafe(self).validate_duplicates(*paths)
    end

    desc "validate-duplicates", "Validate RBI content"
    def validate_duplicates(*paths)
      logger = self.logger
      paths << DEFAULT_PATH if paths.empty?

      files = measure_duration("Listing files", logger) do
        T.unsafe(Parser).list_files(*paths)
      end

      trees = measure_duration("Parsing files", logger) do
        files.map do |file|
          T.unsafe(Parser).parse_file(file)
        end
      end

      res, errors = measure_duration("Validating duplicates", logger) do
        Validators::Duplicates.validate(trees)
      end

      if res
        logger.info("No duplicate RBI definitions were found.")
      else
        errors.each { |error| logger.error(error.to_s) }
      end
    end

    no_commands do
      def logger
        level = options[:verbose] ? Logger::DEBUG : Logger::INFO
        Logger.new(level: level, color: options[:color], quiet: options[:quiet])
      end
    end
  end
end
