# typed: true
# frozen_string_literal: true

require "thor"

module RBI
  class CLI < ::Thor
    extend T::Sig

    DEFAULT_PATH = "sorbet/rbi"

    desc "validate", "Validate RBI content"
    def validate(*paths)
      T.unsafe(self).validate_duplicates(*paths)
    end

    desc "validate-duplicates", "Validate RBI content"
    def validate_duplicates(*paths)
      paths << DEFAULT_PATH if paths.empty?

      files = T.unsafe(Parser).list_files(*paths)
      trees = files.map do |file|
        T.unsafe(Parser).parse_file(file)
      end

      index = Index.new
      trees.each { |tree| index.visit(tree) }

      index.pretty_print
      # trees.each do |tree|
      #   tree.print
      # end
    end

    no_commands do
    end
  end
end
