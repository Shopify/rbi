#!/usr/bin/env ruby
# typed: strict
# frozen_string_literal: true

require "spoom"

FileUtils.rm_rf("tmp/rbi")
rbi_context = Spoom::Context.new("tmp/rbi")
rbi_context.write!("lib/.mkdir", "")

FileUtils.cp_r("lib", rbi_context.absolute_path)
FileUtils.cp_r("Gemfile", rbi_context.absolute_path)
FileUtils.cp_r("Gemfile.lock", rbi_context.absolute_path)
FileUtils.cp_r("rbi.gemspec", rbi_context.absolute_path)

res = rbi_context.exec("bundle install")

unless res.status
  $stderr.puts "Error: bundle install failed"
  $stderr.puts res.err
  exit(1)
end

res = rbi_context.exec("bundle exec spoom srb sigs translate --from rbs --to rbi")

unless res.status
  $stderr.puts "Error: spoom srb sigs translate --from rbs --to rbi tmp/rbi failed"
  $stderr.puts res.err
  exit(1)
end

rbi_context.write!("lib/rbi.rb", rbi_context.read("lib/rbi.rb").gsub("require \"sorbet-runtime\"", <<~RB))
  require "sorbet-runtime"

  class Module
    include T::Sig
  end
RB

tapioca_context = Spoom::Context.new("tmp/tapioca")

tapioca_context.write!("Gemfile", <<~RB)
  source "https://rubygems.org"

  gem "tapioca"
  gem "rbi", path: "../rbi"
RB

res = tapioca_context.exec("bundle install")

unless res.status
  $stderr.puts "Error: tapioca install failed"
  $stderr.puts res.err
  exit(1)
end

res = tapioca_context.exec("bundle exec tapioca gem rbi")

unless res.status
  $stderr.puts "Error: tapioca gem failed"
  $stderr.puts res.err
  exit(1)
end

FileUtils.rm_rf("rbi/")
FileUtils.mkdir_p("rbi/")
FileUtils.cp("tmp/tapioca/sorbet/rbi/gems/rbi@0.2.4.rbi", "rbi/rbi.rbi")

# rbi_context.destroy!

# unless res
#   $stderr.puts "Error: spoom srb sigs translate --from rbs --to rbi tmp/rbi failed"
#   exit(1)
# end

# context = Spoom::Context.new
# context.add_dir("tmp/rbi")
# context.add_dir("lib")

# context.run_all_linters

# check = ARGV.include?("--check")

# rb_files = Dir.glob("lib/**/*.rb")
# rbi_dir = if check
#   "tmp/rbi/"
# else
#   "rbi/"
# end

# FileUtils.rm_rf(rbi_dir)
# FileUtils.mkdir_p(rbi_dir)

# rb_files.each do |file|
#   rbi_file = File.join(rbi_dir, file.gsub(".rb", ".rbi"))
#   rbi_path = File.dirname(rbi_file)

#   FileUtils.mkdir_p(rbi_path)

#   tree = RBI::Parser.parse_file(file)
#   tree.translate_rbs_sigs!

#   File.write(rbi_file, tree.string)
# end

# if check
#   status = system("diff -r rbi/ tmp/rbi/")
#   FileUtils.rm_rf(rbi_dir)

#   if status
#     $stderr.puts "Success: rbi files are in sync"
#     exit(0)
#   else
#     $stderr.puts "\nError: rbi files are out of sync"
#     $stderr.puts "\nRun `bin/export-rbis` to update the rbi files"
#     exit(1)
#   end
# end
