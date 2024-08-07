# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class ParserTest < Minitest::Test
    include TestHelper

    def test_parse_scopes
      rbi = <<~RBI
        module Foo; end
        class Bar; end
        class Bar::Baz < Bar; end
        class ::Foo::Bar::Baz < ::Foo::Bar; end
        class << self; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_nested_scopes
      rbi = <<~RBI
        module Foo
          class Bar
            class Baz < Bar
              class << self; end
            end
          end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_structs
      rbi = <<~RBI
        A = Struct.new
        B = Struct.new(:a, :b)
        C = Struct.new(:a, :b, keyword_init: false)
        D = Struct.new(:a, :b, keyword_init: true)
        E = ::Struct.new(:a, :b, foo: bar)
        F = Struct.new(:a, :b, keyword_init: true) { def m; end }
        G = Struct.new do
          include Foo
          attr_reader :a
          def m1; end
          def m2; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        A = ::Struct.new
        B = ::Struct.new(:a, :b)
        C = ::Struct.new(:a, :b)
        D = ::Struct.new(:a, :b, keyword_init: true)
        E = ::Struct.new(:a, :b)

        F = ::Struct.new(:a, :b, keyword_init: true) do
          def m; end
        end

        G = ::Struct.new do
          include Foo
          attr_reader :a
          def m1; end
          def m2; end
        end
      RBI
    end

    def test_parse_constants
      rbi = <<~RBI
        Foo = 42
        Bar = "foo"
        Baz = Bar
        A = nil
        B = :s
        C = T.nilable(String)
        D = A::B::C
        A::B::C = Foo
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_attributes
      rbi = <<~RBI
        attr_reader :a
        attr_writer :a, :b
        attr_accessor :a, :b, :c

        sig { returns(String) }
        attr_reader :a

        sig { returns(T.nilable(String)) }
        attr_accessor :a, :b, :c
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_methods
      rbi = <<~RBI
        def m1; end
        def self.m2; end
        def m3(a, b = 42, *c, d:, e: "bar", **f, &g); end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_sigs
      rbi = <<~RBI
        sig { void }
        sig(:final) { void }
        sig { returns(String) }
        sig { params.returns }
        sig { checked().type_parameters().params().returns() }
        sig { params(a: T.untyped, b: T::Array[String]).returns(T::Hash[String, Integer]) }
        sig { abstract.params(a: Integer).void }
        sig { checked(:never).returns(T::Array[String]) }
        sig { override.params(printer: Spoom::LSP::SymbolPrinter).void }
        sig { returns(T.nilable(String)) }
        sig { params(requested_generators: T::Array[String]).returns(T.proc.params(klass: Class).returns(T::Boolean)) }
        sig { type_parameters(:U).params(step: Integer, _blk: T.proc.returns(T.type_parameter(:U))).returns(T.type_parameter(:U)) }
        sig { type_parameters(:A, :B).params(a: T::Array[T.type_parameter(:A)], fa: T.proc.params(item: T.type_parameter(:A)).returns(T.untyped), b: T::Array[T.type_parameter(:B)], fb: T.proc.params(item: T.type_parameter(:B)).returns(T.untyped)).returns(T::Array[[T.type_parameter(:A), T.type_parameter(:B)]]) }
        sig { returns({ item_id: String, tax_code: String, name: String, rate: BigDecimal, rate_type: String, amount: BigDecimal, subdivision: String, jurisdiction: String, exempt: T::Boolean, reasons: T::Array[String] }) }
        def foo; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        sig { void }
        sig(:final) { void }
        sig { returns(String) }
        sig { void }
        sig { void }
        sig { params(a: T.untyped, b: T::Array[String]).returns(T::Hash[String, Integer]) }
        sig { abstract.params(a: Integer).void }
        sig { checked(:never).returns(T::Array[String]) }
        sig { override.params(printer: Spoom::LSP::SymbolPrinter).void }
        sig { returns(T.nilable(String)) }
        sig { params(requested_generators: T::Array[String]).returns(T.proc.params(klass: Class).returns(T::Boolean)) }
        sig { type_parameters(:U).params(step: Integer, _blk: T.proc.returns(T.type_parameter(:U))).returns(T.type_parameter(:U)) }
        sig { type_parameters(:A, :B).params(a: T::Array[T.type_parameter(:A)], fa: T.proc.params(item: T.type_parameter(:A)).returns(T.untyped), b: T::Array[T.type_parameter(:B)], fb: T.proc.params(item: T.type_parameter(:B)).returns(T.untyped)).returns(T::Array[[T.type_parameter(:A), T.type_parameter(:B)]]) }
        sig { returns({ item_id: String, tax_code: String, name: String, rate: BigDecimal, rate_type: String, amount: BigDecimal, subdivision: String, jurisdiction: String, exempt: T::Boolean, reasons: T::Array[String] }) }
        def foo; end
      RBI
    end

    def test_parse_dangling_sigs
      rbi = <<~RBI
        class Foo
          sig { void }
        end

        module Bar
          class << self
            sig { void }
          end
          sig { void }
        end
        sig { void }
        sig { returns(A) }
      RBI

      out = Parser.parse_string(rbi)
      assert_equal(rbi, out.string)
    end

    def test_parse_sig_standalone
      rbi = <<~RBI
        sig { void }
        sig { returns(A) }
      RBI

      out = Parser.parse_string(rbi)
      assert_equal(rbi, out.string)
    end

    def test_parse_sig_comments
      rbi = <<~RBI
        # Sig comment
        sig { void }
        # Multi line
        # sig comment
        sig { void }
      RBI

      out = Parser.parse_string(rbi)
      assert_equal(rbi, out.string)
    end

    def test_parse_methods_with_visibility
      rbi = <<~RBI
        private def m1; end
        protected def self.m2; end
        private attr_reader :a
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_mixins
      rbi = <<~RBI
        class Foo
          include A
          extend A
          include self
          extend self
          include T.class_of(Bar)
          extend T::Array[Bar]
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_visibility_labels
      rbi = <<~RBI
        public
        def m1; end
        protected
        def m2; end
        private
        def m3; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_visibility_labels_with_comments
      rbi = <<~RBI
        # Public
        public

        # Protected
        protected

        # Private
        private
      RBI

      out = Parser.parse_string(rbi)
      assert_equal(rbi, out.string)
    end

    def test_parse_t_struct
      rbi = <<~RBI
        class Foo < T::Struct
          const :a, A
          const :b, B, default: B.new
          prop :c, C
          prop(:d, D, default: D.new)
          def foo; end
        end
      RBI

      tree = parse_rbi(rbi)

      # Make sure the T::Struct is not parsed as a normal class
      assert_equal(TStruct, tree.nodes.first.class)

      assert_equal(<<~RBI, tree.string)
        class Foo < T::Struct
          const :a, A
          const :b, B, default: B.new
          prop :c, C
          prop :d, D, default: D.new
          def foo; end
        end
      RBI
    end

    def test_parse_t_enums
      rbi = <<~RBI
        class Foo < T::Enum
          enums do
            A = new
            B = new
            C = new
          end

          def baz; end
        end
      RBI

      tree = parse_rbi(rbi)

      # Make sure the enums are not parsed as normal classes
      enum = tree.nodes.first
      assert_equal(TEnum, enum.class)

      assert_equal(rbi, tree.string)
    end

    def test_parse_t_enums_with_one_value
      rbi = <<~RBI
        class Foo < T::Enum
          enums do
            A = new
          end

          def baz; end
        end
      RBI

      tree = parse_rbi(rbi)

      # Make sure the enums are not parsed as normal classes
      enum = tree.nodes.first
      assert_equal(TEnum, enum.class)

      assert_equal(rbi, tree.string)
    end

    def test_parse_t_enums_ignore_malformed_blocks
      rbi = <<~RBI
        class Foo < T::Enum
          enums
        end

        class Bar < T::Enum
          enums 1, 2
        end
      RBI

      tree = parse_rbi(rbi)

      # Make sure the enums are not parsed as normal classes
      enum = tree.nodes.first
      assert_equal(TEnum, enum.class)

      assert_equal(rbi, tree.string)
    end

    def test_parse_helpers_vs_sends
      rbi = <<~RBI
        abstract!
        sealed!
        interface!
        x!
        foo!
      RBI

      tree = parse_rbi(rbi)

      # Make sure the helpers are properly parsed as `Helper` classes
      assert_equal(2, tree.nodes.grep(Send).size) # `x!` and `foo!`
      assert_equal(3, tree.nodes.grep(Helper).size)

      assert_equal(rbi, tree.string)
    end

    def test_parse_t_enums_with_comments
      rbi = <<~RBI
        # Comment 1
        class Foo < T::Enum
          enums do
            # Comment 2
            A = new

            # Comment 3
            B = new

            # Comment 4
            C = new
          end

          # Comment 5
          def baz; end
        end
      RBI

      tree = Parser.parse_string(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_sorbet_helpers
      rbi = <<~RBI
        class Foo
          abstract!
          sealed!
          interface!
          mixes_in_class_methods A
          requires_ancestor { A }
        end
      RBI

      tree = parse_rbi(rbi)

      # Make sure the helpers are properly parsed as `Helper` classes
      cls = T.cast(tree.nodes.first, Class)
      assert_equal(0, cls.nodes.grep(Send).size)
      assert_equal(3, cls.nodes.grep(Helper).size)
      assert_equal(1, cls.nodes.grep(MixesInClassMethods).size)
      assert_equal(1, cls.nodes.grep(RequiresAncestor).size)

      assert_equal(rbi, tree.string)
    end

    def test_parse_sorbet_type_members_and_templates
      rbi = <<~RBI
        class Foo
          A = type_member
          B = type_member(:in)
          C = type_member(:out) {}
          D = type_member(lower: A)
          E = type_member(upper: A)
          F = type_member(:in, fixed: A)
          G = type_template
          H = type_template(:in)
          I = type_template(:tree, lower: A)
        end
      RBI

      tree = Parser.parse_string(rbi)

      # Make sure the type members and templates are not parsed as constants
      cls = T.must(tree.nodes.grep(Class).first)
      assert_equal(0, cls.nodes.grep(Const).size)
      assert_equal(9, cls.nodes.grep(TypeMember).size)

      assert_equal(rbi, tree.string)
    end

    def test_parse_root_tree_location
      rbi = <<~RBI
        module Foo; end
        class Bar; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal("-:1:0-2:14", tree.loc.to_s)
    end

    def test_parse_arbitrary_sends
      rbi = <<~RBI
        class ActiveRecord::Base
          class_attribute :typed_stores, :store_accessors, instance_accessor: false, default: "Foo"
          foo bar, "bar", :bar
          private :foo
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_scopes_locations
      rbi = <<~RBI
        module Foo; end
        class Bar; end
        class Baz < Bar; end
        class << self; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-1:15
        module Foo; end
        # -:2:0-2:14
        class Bar; end
        # -:3:0-3:20
        class Baz < Bar; end
        # -:4:0-4:18
        class << self; end
      RBI
    end

    def test_parse_nested_scopes_locations
      rbi = <<~RBI
        module Foo
          class Bar
            class Baz < Bar
              class << self; end
            end
          end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-7:3
        module Foo
          # -:2:2-6:5
          class Bar
            # -:3:4-5:7
            class Baz < Bar
              # -:4:6-4:24
              class << self; end
            end
          end
        end
      RBI
    end

    def test_parse_struct_locations
      rbi = <<~RBI
        Foo = Struct.new(:a) do
          def foo; end
          class Bar; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-4:3
        Foo = ::Struct.new(:a) do
          # -:2:2-2:14
          def foo; end
          # -:3:2-3:16
          class Bar; end
        end
      RBI
    end

    def test_parse_constants_locations
      rbi = <<~RBI
        Foo = 42
        Bar = "foo"
        ::Baz = Bar
        A::B::C = Foo
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-1:8
        Foo = 42
        # -:2:0-2:11
        Bar = "foo"
        # -:3:0-3:11
        ::Baz = Bar
        # -:4:0-4:13
        A::B::C = Foo
      RBI
    end

    def test_parse_attributes_locations
      rbi = <<~RBI
        attr_reader :a
        attr_writer :a, :b
        attr_accessor :a, :b, :c

        sig { returns(String) }
        attr_reader :a

        sig { returns(T.nilable(String)) }
        attr_accessor :a, :b, :c
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-1:14
        attr_reader :a
        # -:2:0-2:18
        attr_writer :a, :b
        # -:3:0-3:24
        attr_accessor :a, :b, :c

        # -:5:0-5:23
        sig { returns(String) }
        # -:6:0-6:14
        attr_reader :a

        # -:8:0-8:34
        sig { returns(T.nilable(String)) }
        # -:9:0-9:24
        attr_accessor :a, :b, :c
      RBI
    end

    def test_parse_methods_locations
      rbi = <<~RBI
        def m1; end
        def self.m2; end
        def m3(a, b = 42, *c, d:, e: "bar", **f, &g); end

        sig { void }
        sig { params(a: A, b: T.nilable(B), b: T.proc.void).returns(R) }
        sig { abstract.override.overridable.void }
        sig { type_parameters(:U, :V).checked(:never).params(a: T.type_parameter(:U)).returns(T.type_parameter(:V)) }
        def m4; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-1:11
        def m1; end
        # -:2:0-2:16
        def self.m2; end
        # -:3:0-3:49
        def m3(a, b = 42, *c, d:, e: "bar", **f, &g); end

        # -:5:0-5:12
        sig { void }
        # -:6:0-6:64
        sig { params(a: A, b: T.nilable(B), b: T.proc.void).returns(R) }
        # -:7:0-7:42
        sig { abstract.override.overridable.void }
        # -:8:0-8:109
        sig { type_parameters(:U, :V).checked(:never).params(a: T.type_parameter(:U)).returns(T.type_parameter(:V)) }
        # -:9:0-9:11
        def m4; end
      RBI
    end

    def test_mixins_locations
      rbi = <<~RBI
        class Foo
          include A
          extend A
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-4:3
        class Foo
          # -:2:2-2:11
          include A
          # -:3:2-3:10
          extend A
        end
      RBI
    end

    def test_parse_visibility_labels_locations
      rbi = <<~RBI
        public
        def m1; end
        protected
        def m2; end
        private
        def m3; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-1:6
        public
        # -:2:0-2:11
        def m1; end
        # -:3:0-3:9
        protected
        # -:4:0-4:11
        def m2; end
        # -:5:0-5:7
        private
        # -:6:0-6:11
        def m3; end
      RBI
    end

    def test_parse_t_struct_locations
      rbi = <<~RBI
        class Foo < T::Struct
          const :a, A
          const :b, B, default: B.new
          prop :c, C
          prop :d, D, default: D.new
          def foo; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-7:3
        class Foo < T::Struct
          # -:2:2-2:13
          const :a, A
          # -:3:2-3:29
          const :b, B, default: B.new
          # -:4:2-4:12
          prop :c, C
          # -:5:2-5:28
          prop :d, D, default: D.new
          # -:6:2-6:14
          def foo; end
        end
      RBI
    end

    def test_t_enums_locations
      rbi = <<~RBI
        class Foo < T::Enum
          enums do
            A = new
            B = new
            C = new
          end
          def baz; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-8:3
        class Foo < T::Enum
          # -:2:2-6:5
          enums do
            # -:3:4-3:11
            A = new
            # -:4:4-4:11
            B = new
            # -:5:4-5:11
            C = new
          end

          # -:7:2-7:14
          def baz; end
        end
      RBI
    end

    def test_parse_sorbet_helpers_locations
      rbi = <<~RBI
        class Foo
          abstract!
          sealed!
          interface!
          mixes_in_class_methods A
          requires_ancestor { A }
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-7:3
        class Foo
          # -:2:2-2:11
          abstract!
          # -:3:2-3:9
          sealed!
          # -:4:2-4:12
          interface!
          # -:5:2-5:26
          mixes_in_class_methods A
          # -:6:2-6:25
          requires_ancestor { A }
        end
      RBI
    end

    def test_parse_type_members_and_templates_locations
      rbi = <<~RBI
        class Foo
          A = type_member
          B = type_template
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string(print_locs: true))
        # -:1:0-4:3
        class Foo
          # -:2:2-2:17
          A = type_member
          # -:3:2-3:19
          B = type_template
        end
      RBI
    end

    def test_comments_in_empty_files
      rbi = <<~RBI
        # typed: false
        # frozen_string_literal: true

        # Some header
        # comments
        # on multiple lines

        # Preserving empty lines
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        # typed: false
        # frozen_string_literal: true

        # Some header
        # comments
        # on multiple lines

        # Preserving empty lines
      RBI
    end

    def test_parse_file_header
      rbi = <<~RBI
        # typed: true

        module A; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        # typed: true

        module A; end
      RBI
    end

    def test_parse_file_headers
      rbi = <<~RBI
        # typed: true
        # frozen_string_literal: true

        module A; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        # typed: true
        # frozen_string_literal: true

        module A; end
      RBI
    end

    def test_parse_file_header_and_node_comment
      rbi = <<~RBI
        # typed: true

        # A comment
        module A; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_file_header_and_node_comments
      rbi = <<~RBI
        # typed: true
        # frozen_string_literal: true

        # Some header for the file

        # Some comment
        # for the module
        module A; end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        # typed: true
        # frozen_string_literal: true

        # Some header for the file

        # Some comment
        # for the module
        module A; end
      RBI
    end

    def test_parse_header_comments
      rbi = <<~RBI
        # A comment
        module A
          # B comment
          class B
            # c comment
            def c(a); end

            # d comment
            attr_reader :a

            # E comment
            E = _
          end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_comments_with_sigs
      rbi = <<~RBI
        module A
          # foo comment
          sig { void }
          def foo; end

          # bar comment
          sig { returns(String) }
          attr_reader :bar

          sig { void }
          # baz comment
          def baz; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        module A
          # foo comment
          sig { void }
          def foo; end

          # bar comment
          sig { returns(String) }
          attr_reader :bar

          # baz comment
          sig { void }
          def baz; end
        end
      RBI
    end

    def test_parse_multiline_comments
      rbi = <<~RBI
        # Foo 1
        # Foo 2
        # Foo 3
        module Foo
          # Bar 1
          # Bar 2
          # Bar 3
          class Bar; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_struct_comments
      rbi = <<~RBI
        # Foo
        Foo = ::Struct.new do
          # Bar
          def bar; end
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_collect_dangling_scope_comments
      rbi = <<~RBI
        # A comment 1
        # A comment 2
        module A
          # B comment
          class B; end
          # A comment 3
          # A comment 4
        end
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_collect_dangling_file_comments
      rbi = <<~RBI
        module A; end
        # Orphan comment1
        # Orphan comment2
      RBI

      tree = parse_rbi(rbi)
      assert_equal(rbi, tree.string)
    end

    def test_parse_params_comments
      rbi = <<~RBI
        def bar; end
        def foo(
          a, # `a` comment
             # `b` comment 1
          b, # `b` comment 2
          c:, # `c` comment
              # `d` comment 1
          d:, # `d` comment 2
          e: _
        ); end
      RBI
      tree = parse_rbi(rbi)
      assert_equal(<<~RBI, tree.string)
        def bar; end

        def foo(
          a, # `a` comment
          b, # `b` comment 1
             # `b` comment 2
          c:, # `c` comment
          d:, # `d` comment 1
              # `d` comment 2
          e: _
        ); end
      RBI
    end

    def test_parse_errors
      e = assert_raises(ParseError) do
        Parser.parse_string(<<~RBI)
          def bar
        RBI
      end
      assert_equal(
        "unexpected end-of-input, assuming it is closing the parent top level context. expected an `end` " \
          "to close the `def` statement.",
        e.message,
      )
      assert_equal("-:2:0", e.location.to_s)

      e = assert_raises(ParseError) do
        Parser.parse_string(<<~RBI)
          private include Foo
        RBI
      end
      assert_equal("Unexpected token `private` before `include Foo`", e.message)
      assert_equal("-:1:0-1:19", e.location.to_s)

      e = assert_raises(ParseError) do
        Parser.parse_string(<<~RBI)
          private class Foo; end
        RBI
      end
      assert_equal("Unexpected token `private` before `class Foo; end`", e.message)
      assert_equal("-:1:0-1:22", e.location.to_s)

      e = assert_raises(ParseError) do
        Parser.parse_string(<<~RBI)
          private CST = 42
        RBI
      end
      assert_equal("Unexpected token `private` before `CST = 42`", e.message)
      assert_equal("-:1:0-1:16", e.location.to_s)
    end

    def test_parse_strings
      trees = Parser.parse_strings([
        "class Foo; end",
        "class Bar; end",
      ])

      assert_equal(<<~RBI, trees.map(&:string).join("\n"))
        class Foo; end

        class Bar; end
      RBI
    end

    def test_parse_real_file
      path = "test_parse_real_file.rbi"

      ::File.write(path, <<~RBI)
        class Foo
          def foo; end
        end
      RBI

      rbi = Parser.parse_file(path).string(print_locs: true)

      assert_equal(<<~RBI, rbi)
        # test_parse_real_file.rbi:1:0-3:3
        class Foo
          # test_parse_real_file.rbi:2:2-2:14
          def foo; end
        end
      RBI

      FileUtils.rm_rf(path)
    end

    def test_parse_real_file_with_error
      path = "test_parse_real_file_with_error.rbi"

      ::File.write(path, <<~RBI)
        class Foo
      RBI

      e = assert_raises(ParseError) do
        Parser.parse_file(path)
      end
      assert_equal(
        "unexpected end-of-input, assuming it is closing the parent top level context. expected an `end` " \
          "to close the `class` statement.",
        e.message,
      )
      assert_equal("test_parse_real_file_with_error.rbi:2:0", e.location.to_s)

      FileUtils.rm_rf(path)
    end

    def test_parse_real_files
      path1 = "test_parse_real_files_1.rbi"
      path2 = "test_parse_real_files_2.rbi"

      ::File.write(path1, "class Foo; end")
      ::File.write(path2, "class Bar; end")

      trees = Parser.parse_files([path1, path2])
      rbis = trees.map { |tree| tree.string(print_locs: true) }

      assert_equal(<<~RBI, rbis.join("\n"))
        # test_parse_real_files_1.rbi:1:0-1:14
        class Foo; end

        # test_parse_real_files_2.rbi:1:0-1:14
        class Bar; end
      RBI

      FileUtils.rm_rf(path1)
      FileUtils.rm_rf(path2)
    end
  end
end
