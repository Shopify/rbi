# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class AttrToMethodsTest < Minitest::Test
    def test_replaces_attr_reader_with_method
      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { returns(Integer) }
        attr_reader :a
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { returns(Integer) }
        def a; end
      RBI
    end

    def test_replaces_attr_writer_with_setter_method
      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { params(a: Integer).void }
        attr_writer :a
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { params(a: Integer).void }
        def a=(a); end
      RBI
    end

    def test_replaces_attr_writer_with_return_type_with_setter_method
      # Sorbet allows either `.void` or `.returns(TheType)`.
      # We'll support both, until Sorbet starts to prefer one or the other.

      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { params(a: Integer).returns(Integer) }
        attr_writer :a
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { params(a: Integer).void }
        def a=(a); end
      RBI
    end

    def test_replaces_attr_accessor_with_getter_and_setter_methods
      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { returns(Integer) }
        attr_accessor :a
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { returns(Integer) }
        def a; end

        # Lorum ipsum...
        sig { params(a: Integer).void }
        def a=(a); end
      RBI
    end

    ### Testing for multiple attributes defined in a single declaration

    def test_replaces_multi_attr_reader_with_methods
      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { returns(Integer) }
        attr_reader :a, :b, :c
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { returns(Integer) }
        def a; end

        # Lorum ipsum...
        sig { returns(Integer) }
        def b; end

        # Lorum ipsum...
        sig { returns(Integer) }
        def c; end
      RBI
    end

    def test_replaces_multi_attr_writer_with_methods
      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { params(a: Integer).void }
        attr_writer :a, :b, :c
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { params(a: Integer).void }
        def a=(a); end

        # Lorum ipsum...
        sig { params(b: Integer).void }
        def b=(b); end

        # Lorum ipsum...
        sig { params(c: Integer).void }
        def c=(c); end
      RBI
    end

    def test_replaces_multi_attr_accessor_with_methods
      rbi = Parser.parse_string(<<~RBI)
        # Lorum ipsum...
        sig { returns(Integer) }
        attr_accessor :a, :b, :c
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        # Lorum ipsum...
        sig { returns(Integer) }
        def a; end

        # Lorum ipsum...
        sig { params(a: Integer).void }
        def a=(a); end

        # Lorum ipsum...
        sig { returns(Integer) }
        def b; end

        # Lorum ipsum...
        sig { params(b: Integer).void }
        def b=(b); end

        # Lorum ipsum...
        sig { returns(Integer) }
        def c; end

        # Lorum ipsum...
        sig { params(c: Integer).void }
        def c=(c); end
      RBI
    end

    ### Testing for sig modifiers
    # We don't test for Abstract, because attribute declarations are treated as though
    # they have always have a method body, and so they could never be abstract.

    def test_replacing_attr_reader_copies_sig_modifiers
      rbi = Parser.parse_string(<<~RBI)
        class GrandParent
          sig { overridable.returns(Integer) }
          attr_reader :a
        end

        class Parent < GrandParent
          sig { override.overridable.returns(Integer) }
          attr_reader :a
        end

        class Child < Parent
          sig(:final) { override.returns(Integer) }
          attr_reader :a
        end
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        class GrandParent
          sig { overridable.returns(Integer) }
          def a; end
        end

        class Parent < GrandParent
          sig { override.overridable.returns(Integer) }
          def a; end
        end

        class Child < Parent
          sig(:final) { override.returns(Integer) }
          def a; end
        end
      RBI
    end

    def test_replacing_attr_writer_copies_sig_modifiers
      rbi = Parser.parse_string(<<~RBI)
        class GrandParent
          sig { overridable.params(a: Integer).void }
          attr_writer :a
        end

        class Parent < GrandParent
          sig { override.overridable.params(a: Integer).void }
          attr_writer :a
        end

        class Child < Parent
          sig(:final) { override.params(a: Integer).void }
          attr_writer :a
        end
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        class GrandParent
          sig { overridable.params(a: Integer).void }
          def a=(a); end
        end

        class Parent < GrandParent
          sig { override.overridable.params(a: Integer).void }
          def a=(a); end
        end

        class Child < Parent
          sig(:final) { override.params(a: Integer).void }
          def a=(a); end
        end
      RBI
    end

    def test_replacing_attr_accessor_copies_sig_modifiers
      rbi = Parser.parse_string(<<~RBI)
        class GrandParent
          sig { overridable.returns(Integer) }
          attr_accessor :a
        end

        class Parent < GrandParent
          sig { override.overridable.returns(Integer) }
          attr_accessor :a
        end

        class Child < Parent
          sig(:final) { override.returns(Integer) }
          attr_accessor :a
        end
      RBI

      rbi.replace_attributes_with_methods!

      assert_equal(<<~RBI, rbi.string)
        class GrandParent
          sig { overridable.returns(Integer) }
          def a; end

          sig { overridable.params(a: Integer).void }
          def a=(a); end
        end

        class Parent < GrandParent
          sig { override.overridable.returns(Integer) }
          def a; end

          sig { override.overridable.params(a: Integer).void }
          def a=(a); end
        end

        class Child < Parent
          sig(:final) { override.returns(Integer) }
          def a; end

          sig(:final) { override.params(a: Integer).void }
          def a=(a); end
        end
      RBI
    end

    def test_raise_on_multiple_sigs
      rbi = Parser.parse_string(<<~RBI)
        sig { returns(Integer) }
        sig { returns(String) }
        attr_accessor :a
      RBI

      e = assert_raises(RBI::UnexpectedMultipleSigsError) { rbi.replace_attributes_with_methods! }

      assert_equal(["Integer", "String"], e.node.sigs.map(&:return_type))
      # This is just to test the message rendering. Please don't depend on the exact message content.
      assert_equal(e.message, <<~MSG)
        This declaration cannot have more than one sig.

        sig { returns(Integer) }
        sig { returns(String) }
        attr_accessor :a
      MSG
    end
  end
end
