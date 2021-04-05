# typed: true
# frozen_string_literal: true

require "thor"

module RBI
  class CLI < ::Thor
    extend T::Sig

    DEFAULT_PATH = "sorbet/rbi"

    class_option :color, type: :boolean, default: true
    class_option :quiet, type: :boolean, default: false, aliases: :q
    class_option :verbose, type: :boolean, default: false, aliases: :v
    class_option :time, type: :boolean, default: false, aliases: :t

    desc "validate", "Validate RBI content"
    def validate(*paths)
      T.unsafe(self).validate_duplicates(*paths)
    end

    desc "validate-duplicates", "Validate RBI content"
    def validate_duplicates(*paths)
      logger = self.logger
      paths << DEFAULT_PATH if paths.empty?

      files = logger.time("Listing files") do
        T.unsafe(Parser).list_files(*paths)
      end

      trees = logger.time("Parsing files") do
        files.map do |file|
          T.unsafe(Parser).parse_file(file)
        end
      end

      res, errors = logger.time("Validating duplicates") do
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
        time = options[:verbose] || options[:time]
        Logger.new(level: level, color: options[:color], quiet: options[:quiet], time: time)
      end
    end
  end
end
