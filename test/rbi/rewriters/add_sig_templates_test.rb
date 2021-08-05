# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class AddSigTemplatesTest < Minitest::Test
    def test_do_not_add_sig_if_already_one
      rbi = RBI::Tree.new

      rbi << RBI::AttrReader.new(:a) do |attr|
        attr.sigs << Sig.new(return_type: "Integer")
      end

      rbi << RBI::Method.new("m") do |meth|
        meth.sigs << Sig.new(return_type: "Integer")
      end

      rbi.add_sig_templates!(with_todo_comment: true)

      assert_equal(<<~RBI, rbi.string)
        sig { returns(Integer) }
        attr_reader :a

        sig { returns(Integer) }
        def m; end
      RBI
    end

    def test_add_empty_sigs_to_attributes
      rbi = RBI::Tree.new
      rbi << RBI::AttrReader.new(:a1)
      rbi << RBI::AttrWriter.new(:a2)
      rbi << RBI::AttrAccessor.new(:a3)

      rbi.add_sig_templates!(with_todo_comment: false)

      assert_equal(<<~RBI, rbi.string)
        sig { returns(T.untyped) }
        attr_reader :a1

        sig { params(a2: T.untyped).returns(T.untyped) }
        attr_writer :a2

        sig { returns(T.untyped) }
        attr_accessor :a3
      RBI
    end

    def test_add_empty_sigs_and_todo_comment_to_attributes
      rbi = RBI::Tree.new
      rbi << RBI::AttrReader.new(:a1)
      rbi << RBI::AttrWriter.new(:a2)
      rbi << RBI::AttrAccessor.new(:a3)

      rbi.add_sig_templates!(with_todo_comment: true)

      assert_equal(<<~RBI, rbi.string)
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
      rbi = RBI::Tree.new
      rbi << RBI::Method.new("m1")
      rbi << RBI::Method.new("m2") do |meth|
        meth << RBI::Param.new("x")
      end
      rbi << RBI::Method.new("m3", is_singleton: true) do |meth|
        meth << RBI::Param.new("x")
        meth << RBI::OptParam.new("y", "42")
        meth << RBI::KwRestParam.new("z")
      end

      rbi.add_sig_templates!(with_todo_comment: false)

      assert_equal(<<~RBI, rbi.string)
        sig { returns(T.untyped) }
        def m1; end

        sig { params(x: T.untyped).returns(T.untyped) }
        def m2(x); end

        sig { params(x: T.untyped, y: T.untyped, z: T.untyped).returns(T.untyped) }
        def self.m3(x, y = 42, **z); end
      RBI
    end

    def test_add_empty_sigs_and_todo_comment_to_methods
      rbi = RBI::Tree.new
      rbi << RBI::Method.new("m1")
      rbi << RBI::Method.new("m2") do |meth|
        meth << RBI::Param.new("x")
      end
      rbi << RBI::Method.new("m3", is_singleton: true) do |meth|
        meth << RBI::Param.new("x")
        meth << RBI::OptParam.new("y", "42")
        meth << RBI::KwRestParam.new("z")
      end

      rbi.add_sig_templates!(with_todo_comment: true)

      assert_equal(<<~RBI, rbi.string)
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
