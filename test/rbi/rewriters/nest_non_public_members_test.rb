# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class NestNonPublicMembersTest < Minitest::Test
    include TestHelper

    def test_nest_non_public_members_in_tree
      tree = parse_rbi(<<~RBI)
        def m1; end
        protected def m2; end
        private def m3; end
        public attr_reader :m4
      RBI

      tree.nest_non_public_members!

      assert_equal(<<~RBI, tree.string)
        def m1; end
        attr_reader :m4

        protected

        def m2; end

        private

        def m3; end
      RBI
    end

    def test_nest_non_public_members_in_scopes
      tree = parse_rbi(<<~RBI)
        module S1
          def m1; end
          protected def m2; end

          class S2
            def m3; end
            private attr_reader :m4

            class << self
              def m5; end
              protected def m6; end
            end
          end
        end
      RBI

      tree.nest_non_public_members!

      assert_equal(<<~RBI, tree.string)
        module S1
          class S2
            class << self
              def m5; end

              protected

              def m6; end
            end

            def m3; end

            private

            attr_reader :m4
          end

          def m1; end

          protected

          def m2; end
        end
      RBI
    end

    def test_nest_non_public_singleton_methods
      tree = parse_rbi(<<~RBI)
        protected def self.m1; end
        private def self.m2; end
        public def self.m3; end
      RBI

      tree.nest_non_public_members!

      assert_equal(<<~RBI, tree.string)
        def self.m3; end

        protected

        def self.m1; end

        private

        def self.m2; end
      RBI
    end
  end
end
