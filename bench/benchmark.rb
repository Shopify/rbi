#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "benchmark"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rbi"

# Build a large RBI tree simulating a typical ActiveRecord model DSL output
#: (?num_methods: Integer, ?num_attrs: Integer, ?num_includes: Integer, ?num_scopes: Integer) -> RBI::Tree
def build_large_tree(num_methods: 200, num_attrs: 20, num_includes: 5, num_scopes: 3)
  tree = RBI::Tree.new

  klass = RBI::Class.new("TestModel", superclass_name: "::ActiveRecord::Base")
  tree << klass

  # Add includes
  num_includes.times do |i|
    klass << RBI::Include.new("Module#{i}")
  end

  # Add extends
  klass << RBI::Extend.new("GeneratedRelationMethods")
  klass << RBI::Extend.new("CommonRelationMethods")

  # Add type members
  klass << RBI::TypeMember.new("Elem", "type_member(fixed: TestModel)")

  # Add attrs
  num_attrs.times do |i|
    attr = RBI::AttrReader.new(:"attr_#{i}")
    attr.sigs << RBI::Sig.new(return_type: "String")
    klass << attr
  end

  # Add methods (mix of public, private, singleton)
  num_methods.times do |i|
    visibility = case i % 10
    when 0..6 then RBI::Public.new
    when 7..8 then RBI::Private.new
    else RBI::Protected.new
    end #: RBI::Visibility

    method = RBI::Method.new(
      "method_#{i}",
      is_singleton: i % 15 == 0,
      visibility: visibility,
      params: [
        RBI::ReqParam.new("arg1"),
        RBI::OptParam.new("arg2", "nil"),
      ],
      sigs: [
        RBI::Sig.new(
          params: [
            RBI::SigParam.new("arg1", "String"),
            RBI::SigParam.new("arg2", "T.nilable(Integer)"),
          ],
          return_type: "T::Boolean",
        ),
      ],
    )
    klass << method
  end

  # Add inner scopes
  num_scopes.times do |i|
    inner = RBI::Module.new("InnerModule#{i}")
    5.times do |j|
      inner << RBI::Method.new("inner_method_#{j}", sigs: [RBI::Sig.new(return_type: "void")])
    end
    klass << inner
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
tree = build_large_tree
formatter.print_file(make_file(tree))

iterations = 100
puts "Benchmarking #{iterations} iterations of format_tree + print on a tree with 200 methods..."
puts

# Benchmark format_tree separately
Benchmark.bm(20) do |x|
  x.report("format_tree") do
    iterations.times do
      tree = build_large_tree
      file = make_file(tree)
      formatter.format_file(file)
    end
  end

  x.report("print_file (full)") do
    iterations.times do
      tree = build_large_tree
      file = make_file(tree)
      formatter.print_file(file)
    end
  end
end

# Also benchmark with a very large tree
puts
puts "Benchmarking with 500 methods (stress test)..."
Benchmark.bm(20) do |x|
  x.report("format_tree") do
    50.times do
      tree = build_large_tree(num_methods: 500)
      file = make_file(tree)
      formatter.format_file(file)
    end
  end

  x.report("print_file (full)") do
    50.times do
      tree = build_large_tree(num_methods: 500)
      file = make_file(tree)
      formatter.print_file(file)
    end
  end
end
