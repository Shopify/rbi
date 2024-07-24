# typed: true
# frozen_string_literal: true

require "rbi"

path = ARGV[0] || "."

Dir[path].each do |file|
  puts "Parsing #{file}"
  rbi = RBI::Parser.parse_file(file)

  # puts rbi.string
  # File.write(file, rbi.string(max_line_length: 120))
rescue RBI::ParseError, RBI::UnexpectedParserError => e
  # no-op
  # puts "Error parsing #{file}: #{e.message}"
  # puts e.backtrace
rescue RBI::Type::Error => e
  puts "Error parsing #{file}: #{e.message}"
  puts e.backtrace
end
