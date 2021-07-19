# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  module Test
    class IndexTest < Minitest::Test
      extend T::Sig

      JSON = <<~JSON
        {
          "foo": {
            "1.0.0": "/path/to/foo@1.0.0.rb",
            "1.0.1": "/path/to/foo@1.0.1.rb"
          },
          "bar": {
            "0.0.1": "/path/to/bar@0.0.1.rb"
          }
        }
      JSON

      def test_empty_index
        index = Index.new

        assert_equal(0, index.size)
        assert_equal([], index.gems)
      end

      def test_index_gems
        index = dummy_index

        assert_equal(2, index.size)
        assert_equal(["foo", "bar"], index.gems)
      end

      def test_has_gem
        index = dummy_index

        assert(index.has_gem?("foo"))
        assert(index.has_gem?("bar"))
        refute(index.has_gem?("baz"))
      end

      def test_versions_for_gem
        index = dummy_index

        assert_equal(["1.0.0", "1.0.1"], index.versions_for_gem("foo"))
        assert_equal(["0.0.1"], index.versions_for_gem("bar"))
        assert_empty(index.versions_for_gem("baz"))
      end

      def test_last_version_for_gem
        index = dummy_index

        assert_equal("1.0.1", index.last_version_for_gem("foo"))
        assert_equal("0.0.1", index.last_version_for_gem("bar"))
        assert_nil(index.last_version_for_gem("baz"))
      end

      def test_has_version_for_gem
        index = dummy_index

        assert(index.has_version_for_gem?("foo", "1.0.0"))
        assert(index.has_version_for_gem?("foo", "1.0.1"))
        refute(index.has_version_for_gem?("foo", "0.0.1"))

        assert(index.has_version_for_gem?("bar", "0.0.1"))
        refute(index.has_version_for_gem?("bar", "0.0.2"))

        refute(index.has_version_for_gem?("baz", "0.0.1"))
      end

      def test_rbi_path
        index = dummy_index

        assert_equal("/path/to/foo@1.0.0.rb", index.rbi_path("foo", "1.0.0"))
        assert_equal("/path/to/foo@1.0.1.rb", index.rbi_path("foo", "1.0.1"))
        assert_nil(index.rbi_path("foo", "0.0.1"))

        assert_equal("/path/to/bar@0.0.1.rb", index.rbi_path("bar", "0.0.1"))
        assert_nil(index.rbi_path("bar", "1.0.0"))

        assert_nil(index.rbi_path("baz", "1.0.0"))
      end

      def test_each
        index = dummy_index

        count = 0
        expected = { "foo" => 2, "bar" => 1 }

        index.each do |name, versions|
          assert(expected.key?(name))
          assert_equal(expected[name], versions.size)
          count += versions.size
        end

        assert_equal(3, count)
      end

      def test_to_pretty_json
        assert_equal(JSON, dummy_index.to_pretty_json)
      end

      def test_from_json
        index = Index.from_json(JSON)

        assert_equal(2, index.size)
        assert_equal(["foo", "bar"], index.gems)
      end

      private

      sig { returns(Index) }
      def dummy_index
        index = Index.new
        index.index("foo", "1.0.0", "/path/to/foo@1.0.0.rb")
        index.index("foo", "1.0.1", "/path/to/foo@1.0.1.rb")
        index.index("bar", "0.0.1", "/path/to/bar@0.0.1.rb")
        index
      end
    end
  end
end
