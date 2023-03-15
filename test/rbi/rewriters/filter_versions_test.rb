# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class FilterVersions < Minitest::Test
    def test_node_meets_requirements
      rbi = <<~RBI
        # @version < 1.0.0
        class Foo; end

        # @version > 1.0.0
        class Bar; end

        # @version = 1.0.0
        class Baz; end

        # @version <= 1.0.0
        class Buzz; end

        # @version >= 1.0.0
        class Beez; end

        # @version > 0.5.0, < 1.0.0
        class Boz; end

        # @version < 0.5.0
        # @version > 1.0.0
        class Biz; end
      RBI
    end
  end
end
