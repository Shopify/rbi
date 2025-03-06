# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class TranslateRBSSigsTest < Minitest::Test
    include TestHelper

    def test_does_nothing_if_no_rbs_comments
      rbi = <<~RBI
        class Foo
          attr_reader :a
          def bar; end
        end
      RBI

      assert_equal(rbi, rewrite(rbi))
    end

    def test_translate_attr_sigs
      tree = rewrite(<<~RBI)
        #: Integer
        attr_reader :a

        #: Integer
        attr_writer :b

        #: Integer
        attr_accessor :c, :d
      RBI

      assert_equal(<<~RBI, tree)
        sig { returns(Integer) }
        attr_reader :a

        sig { params(b: Integer).returns(Integer) }
        attr_writer :b

        sig { returns(Integer) }
        attr_accessor :c, :d
      RBI
    end

    private

    #: (String) -> String
    def rewrite(rbi)
      tree = parse_rbi(rbi)
      tree.translate_rbs_sigs!
      tree.string
    end
  end
end
