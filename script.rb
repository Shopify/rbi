# typed: true
# frozen_string_literal: true

require "rbi"

def collect_files(paths)
  paths << "." if paths.empty?

  files = paths.flat_map do |path|
    if File.file?(path)
      [path]
    else
      Dir.glob("#{path}/**/*.rb")
    end
  end

  if files.empty?
    raise "No files to transform"
  end

  files
end

collect_files(ARGV).each do |file|
  parser = RBI::Parser.new
  parser.parse_file(file)
rescue RBI::ParseError => e
  puts "Error parsing #{file}:#{e.location.begin_line}:#{e.location.begin_column}: #{e.message}"
end
