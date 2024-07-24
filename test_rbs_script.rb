# typed: strict
# frozen_string_literal: true

require "rbi"
require "fileutils"
require "rbs"

path = ARGV[0]
out_dir = ARGV[1]

unless path && out_dir
  $stderr.puts "Usage: ruby script.rb <path> <out-dir>"
  exit(1)
end

FileUtils.mkdir_p(out_dir)

rbi_files = if File.file?(path)
  [path]
else
  Dir.glob("#{path}/**/*.rbi")
end
puts rbi_files.inspect

rbi_files.each do |file|
  puts "## Processing #{file}..."
  name = File.basename(file, ".rbi")

  rbi = RBI::Parser.parse_file(file)
  # rbi.inline_visibilities!
  rbi.flatten_singleton_methods!
  rbi.rbs_rewrite!

  rbs = rbi.rbs_string
  rbs_path = File.join(out_dir, "#{name}.rbs")
  File.write(rbs_path, rbs)

  puts "  -> #{rbs_path}"
  rbs = RBS::Buffer.new(content: rbs, name: rbs_path)
  RBS::Parser.parse_signature(rbs)
end

# rbs = <<~RBS
#   class Object
#     def foo: ?{ (?) -> untyped } -> void
#   end
# RBS
# rbs = RBS::Buffer.new(content: rbs, name: "")
# RBS::Parser.parse_signature(rbs)
