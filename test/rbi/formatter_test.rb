# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FormatterTest < Minitest::Test
    include TestHelper

    def test_format_add_sig_templates
      rbi = <<~RBI
        module Foo
          def foo(a, b); end
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(add_sig_templates: false).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(add_sig_templates: true).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          # TODO: fill in signature with appropriate type information
          sig { params(a: T.untyped, b: T.untyped).returns(T.untyped) }
          def foo(a, b); end
        end
      RBI
    end

    def test_format_replace_attributes_with_methods
      rbi = <<~RBI
        module Foo
          attr_reader :a
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(replace_attributes_with_methods: false).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(replace_attributes_with_methods: true).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          def a; end
        end
      RBI
    end

    def test_format_group_nodes
      rbi = <<~RBI
        module Foo
          def foo; end
          attr_reader :a
          def bar(a, b); end
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(group_nodes: false).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(group_nodes: true).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          def foo; end
          def bar(a, b); end

          attr_reader :a
        end
      RBI
    end

    def test_format_max_line_length
      rbi = <<~RBI
        module Foo
          sig { params(a: T.untyped, b: T.untyped).returns(T.untyped) }
          def foo(a, b); end
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(max_line_length: nil).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(max_line_length: 10).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          sig do
            params(
              a: T.untyped,
              b: T.untyped
            ).returns(T.untyped)
          end
          def foo(a, b); end
        end
      RBI
    end

    def test_format_nest_singleton_methods
      rbi = <<~RBI
        module Foo
          def self.foo; end
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(nest_singleton_methods: false).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(nest_singleton_methods: true).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          class << self
            def foo; end
          end
        end
      RBI
    end

    def test_format_nest_non_public_methods
      rbi = <<~RBI
        module Foo
          private def foo; end
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(nest_non_public_members: false).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(nest_non_public_members: true).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          private

          def foo; end
        end
      RBI
    end

    def test_format_sort_nodes
      rbi = <<~RBI
        module Foo
          def foo; end
          def bar(a, b); end
        end
      RBI

      file = File.new
      file.root = parse_rbi(rbi)

      out = Formatter.new(sort_nodes: false).print_file(file)
      assert_equal(rbi, out)

      out = Formatter.new(sort_nodes: true).print_file(file)
      assert_equal(<<~RBI, out)
        module Foo
          def bar(a, b); end
          def foo; end
        end
      RBI
    end
  end
end
