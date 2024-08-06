# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class AddSigTemplatesTest < Minitest::Test
    include TestHelper

    def test_do_not_add_sig_if_already_one
      tree = parse_rbi(<<~RBI)
        sig { returns(Integer) }
        attr_reader :a

        sig { returns(Integer) }
        def foo; end

        def bar; end
      RBI

      tree.add_sig_templates!(with_todo_comment: true)

      assert_equal(<<~RBI, tree.string)
        sig { returns(Integer) }
        attr_reader :a

        sig { returns(Integer) }
        def foo; end

        # TODO: fill in signature with appropriate type information
        sig { returns(T.untyped) }
        def bar; end
      RBI
    end

    def test_add_empty_sigs_to_attributes
      tree = parse_rbi(<<~RBI)
        attr_reader :a1
        attr_writer :a2
        attr_accessor :a3
      RBI

      tree.add_sig_templates!(with_todo_comment: false)

      assert_equal(<<~RBI, tree.string)
        sig { returns(T.untyped) }
        attr_reader :a1

        sig { params(a2: T.untyped).returns(T.untyped) }
        attr_writer :a2

        sig { returns(T.untyped) }
        attr_accessor :a3
      RBI
    end

    def test_add_empty_sigs_and_todo_comment_to_attributes
      tree = parse_rbi(<<~RBI)
        attr_reader :a1
        attr_writer :a2
        attr_accessor :a3
      RBI

      tree.add_sig_templates!(with_todo_comment: true)

      assert_equal(<<~RBI, tree.string)
        # TODO: fill in signature with appropriate type information
        sig { returns(T.untyped) }
        attr_reader :a1

        # TODO: fill in signature with appropriate type information
        sig { params(a2: T.untyped).returns(T.untyped) }
        attr_writer :a2

        # TODO: fill in signature with appropriate type information
        sig { returns(T.untyped) }
        attr_accessor :a3
      RBI
    end

    def test_add_empty_sigs_to_methods
      tree = parse_rbi(<<~RBI)
        def m1; end
        def m2(x); end
        def self.m3(x, y = 42, **z); end
      RBI

      tree.add_sig_templates!(with_todo_comment: false)

      assert_equal(<<~RBI, tree.string)
        sig { returns(T.untyped) }
        def m1; end

        sig { params(x: T.untyped).returns(T.untyped) }
        def m2(x); end

        sig { params(x: T.untyped, y: T.untyped, z: T.untyped).returns(T.untyped) }
        def self.m3(x, y = 42, **z); end
      RBI
    end

    def test_add_empty_sigs_and_todo_comment_to_methods
      tree = parse_rbi(<<~RBI)
        def m1; end
        def m2(x); end
        def self.m3(x, y = 42, **z); end
      RBI

      tree.add_sig_templates!(with_todo_comment: true)

      assert_equal(<<~RBI, tree.string)
        # TODO: fill in signature with appropriate type information
        sig { returns(T.untyped) }
        def m1; end

        # TODO: fill in signature with appropriate type information
        sig { params(x: T.untyped).returns(T.untyped) }
        def m2(x); end

        # TODO: fill in signature with appropriate type information
        sig { params(x: T.untyped, y: T.untyped, z: T.untyped).returns(T.untyped) }
        def self.m3(x, y = 42, **z); end
      RBI
    end
  end
end
