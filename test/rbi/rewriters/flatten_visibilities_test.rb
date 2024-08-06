# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FlattenVisibilitiesTest < Minitest::Test
    include TestHelper

    def test_flatten_visibilities_in_tree
      tree = parse_rbi(<<~RBI)
        def m1; end
        def m2; end
        protected
        def m3; end
        def m4; end
        private
        def m5; end
        def m6; end
      RBI

      tree.flatten_visibilities!

      assert_equal(<<~RBI, tree.string)
        def m1; end
        def m2; end
        protected def m3; end
        protected def m4; end
        private def m5; end
        private def m6; end
      RBI
    end

    def test_flatten_visibilityies_in_scopes
      tree = parse_rbi(<<~RBI)
        module S1
          class S2
            class << self
              def m1; end

              protected

              def m2; end
              attr_reader :m3
            end

            def m4; end

            private

            def m5; end
            attr_writer m6
          end

          def m7; end

          protected

          def m8; end
        end
      RBI

      tree.flatten_visibilities!

      assert_equal(<<~RBI, tree.string)
        module S1
          class S2
            class << self
              def m1; end
              protected def m2; end
              protected attr_reader :m3
            end

            def m4; end
            private def m5; end
            private attr_writer :m6
          end

          def m7; end
          protected def m8; end
        end
      RBI
    end

    def test_flatten_visibilities_for_singleton_methods
      tree = parse_rbi(<<~RBI)
        def self.m1; end

        protected

        def self.m2; end

        private

        def self.m3; end
      RBI

      tree.flatten_visibilities!

      assert_equal(<<~RBI, tree.string)
        def self.m1; end
        protected def self.m2; end
        private def self.m3; end
      RBI
    end
  end
end
