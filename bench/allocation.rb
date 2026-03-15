#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rbi"

# Build a large RBI tree simulating a typical ActiveRecord model DSL output
#: (?num_methods: Integer) -> RBI::Tree
def build_tree(num_methods: 200)
  tree = RBI::Tree.new
  klass = RBI::Class.new("TestModel", superclass_name: "::ActiveRecord::Base")
  tree << klass
  5.times { |i| klass << RBI::Include.new("Mod#{i}") }
  klass << RBI::Extend.new("RelMethods")
  num_methods.times do |i|
    vis = case i % 10
    when 0..6 then RBI::Public::DEFAULT
    when 7..8 then RBI::Private.new
    else RBI::Protected.new
    end #: RBI::Visibility
    m = RBI::Method.new(
      "m_#{i}",
      params: [RBI::ReqParam.new("a"), RBI::OptParam.new("b", "nil")],
      is_singleton: i % 15 == 0,
      visibility: vis,
      sigs: [RBI::Sig.new(
        params: [RBI::SigParam.new("a", "String"), RBI::SigParam.new("b", "T.nilable(Integer)")],
        return_type: "T::Boolean",
      )],
    )
    klass << m
  end
  tree
end

#: (RBI::Tree tree) -> RBI::File
def make_file(tree)
  file = RBI::File.new(strictness: "true")
  tree.nodes.each { |n| file << n }
  file
end

formatter = RBI::Formatter.new(
  group_nodes: true,
  sort_nodes: true,
  nest_singleton_methods: true,
  nest_non_public_members: true,
)

# Warmup
3.times { formatter.print_file(make_file(build_tree)) }

# Measure allocations per phase
GC.start
GC.disable
b1 = GC.stat(:total_allocated_objects)
f = make_file(build_tree)
b2 = GC.stat(:total_allocated_objects)
formatter.format_file(f)
b3 = GC.stat(:total_allocated_objects)
_ = f.string
b4 = GC.stat(:total_allocated_objects)
GC.enable

puts "Object allocations (200-method tree):"
puts "  build:  #{b2 - b1}"
puts "  format: #{b3 - b2}"
puts "  render: #{b4 - b3}"
puts "  total:  #{b4 - b1}"
