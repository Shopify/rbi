# typed: ignore
# frozen_string_literal: true

require "benchmark/ips"
require "prism"

def random_count
  rand(1..100)
end

def random_string(n)
  ("A".."Z").to_a.sample(n).join
end

def random_name
  prefix = ["", ",", "::", "a"].sample
  suffix = random_string(random_count)
  "#{prefix}#{suffix}"
end

names = 10_000.times.map do |_i|
  random_name
end

rbs = names.map do |name|
  "class self::#{name}; end"
end

puts rbs

Benchmark.ips do |x|
  prism_result = nil
  vm_result = nil

  x.report("Prism") do
    prism_result = rbs.map do |rb|
      res = Prism.parse(rb)
      res.errors.empty?
    end
  end

  x.report("VM") do
    vm_result = rbs.each do |rb|
      RubyVM::InstructionSequence.compile(rb)
      true
    rescue SyntaxError
      false
    end
  end

  x.compare!

  raise unless prism_result == vm_result
end
