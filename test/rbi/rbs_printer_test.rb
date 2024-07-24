# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class RBSPrinterTest < Minitest::Test
    extend T::Sig

    def test_print_empty_file
      assert_empty(File.new.rbs_string)
    end

    def test_print_files_without_strictness
      file = File.new
      file.root << Module.new("Foo")

      assert_equal(<<~RBI, file.rbs_string)
        module Foo
        end
      RBI
    end

    def test_print_files_with_strictness_but_omit_it
      file = File.new(strictness: "true")
      file.root << Module.new("Foo")

      assert_equal(<<~RBI, file.rbs_string)
        module Foo
        end
      RBI
    end

    def test_print_files_with_comments_but_no_strictness
      file = File.new(comments: [
        Comment.new("This is a"),
        Comment.new("Multiline Comment"),
      ])
      file.root << Module.new("Foo")

      assert_equal(<<~RBI, file.rbs_string)
        # This is a
        # Multiline Comment

        module Foo
        end
      RBI
    end

    def test_print_files_with_comments_and_strictness
      file = File.new(strictness: "true", comments: [
        Comment.new("This is a"),
        Comment.new("Multiline Comment"),
      ])
      file.root << Module.new("Foo")

      assert_equal(<<~RBI, file.rbs_string)
        # This is a
        # Multiline Comment

        module Foo
        end
      RBI
    end

    def test_print_modules_and_classes
      rbi = parse_rbi(<<~RBI)
        module Foo; end
        class Bar; end
        class Baz < Bar; end
        class << self; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        module Foo
        end

        class Bar
        end

        class Baz < Bar
        end

        class << self
        end
      RBI
    end

    def test_print_nested_scopes
      rbi = parse_rbi(<<~RBI)
        module Foo
          class Bar
            class Baz < Bar
              class << self; end
            end
          end
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        module Foo
          class Bar
            class Baz < Bar
              class << self
              end
            end
          end
        end
      RBI
    end

    def test_print_structs
      rbi = parse_rbi(<<~RBI)
        Foo = Struct.new(:foo, :bar)
        Bar = Struct.new(:bar, keyword_init: true) do
          def bar_method; end
        end
        Baz = Struct.new(:baz) do
          def baz_method; end
          class << self
            def baz_class_method; end
          end
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        Foo = ::Struct.new(:foo, :bar)

        Bar = ::Struct.new(:bar, keyword_init: true) do
          def bar_method: (*untyped) -> untyped
        end

        Baz = ::Struct.new(:baz) do
          def baz_method: (*untyped) -> untyped

          class << self
            def baz_class_method: (*untyped) -> untyped
          end
        end
      RBI
    end

    def test_print_constants_with_values_as_untyped
      rbi = parse_rbi(<<~RBI)
        Foo = 42
        Bar = 'foo'
        Baz = Bar
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        Foo: untyped
        Bar: untyped
        Baz: untyped
      RBI
    end

    def test_print_constants_with_t_let_as_typed
      rbi = parse_rbi(<<~RBI)
        Foo = T.let(42, Integer)
        Bar = T.let(some.complex_thing(42), String)
        Baz = T.let(T.unsafe(foo), Object)
        Qux = T.let(T.unsafe(foo), T.untyped)
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        Foo: Integer
        Bar: String
        Baz: Object
        Qux: untyped
      RBI
    end

    def test_print_attributes
      rbi = parse_rbi(<<~RBI)
        attr_reader :foo
        private attr_writer :bar, :baz
        protected attr_accessor :qux
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        attr_reader foo: untyped
        private attr_writer bar: untyped
        private attr_writer baz: untyped
        attr_accessor qux: untyped
      RBI
    end

    def test_print_attributes_with_signatures
      rbi = parse_rbi(<<~RBI)
        sig { returns(Integer) }
        attr_accessor :foo

        sig { returns(String) }
        attr_accessor :bar
      RBI

      # With RBS, attributes can only have one and only one return type
      # if we have multiple signatures we just use the return type of the first one
      # and ignore the rest
      assert_equal(<<~RBI, rbi.rbs_string)
        attr_accessor foo: Integer
        attr_accessor bar: String
      RBI
    end

    def test_print_methods_without_signature
      rbi = parse_rbi(<<~RBI)
        def foo; end
      RBI

      # If a method doesn't have a signature, we assume it's untyped
      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: (*untyped) -> untyped
      RBI
    end

    def test_print_methods_with_visibility
      rbi = parse_rbi(<<~RBI)
        def m1; end
        public def m2; end
        private def m3; end
        protected def m4; end
        def self.m5; end
        private def self.m6; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        def m1: (*untyped) -> untyped
        def m2: (*untyped) -> untyped
        private def m3: (*untyped) -> untyped
        protected def m4: (*untyped) -> untyped
        def self.m5: (*untyped) -> untyped
        private def self.m6: (*untyped) -> untyped
      RBI
    end

    def test_print_methods_with_parameters
      rbi = parse_rbi(<<~RBI)
        def foo(a, b = 42, *c, d:, e: 'bar', **f, &g); end
      RBI

      # Actual method parameters are ignored, RBS translation relies on the RBI signature
      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: (*untyped) -> untyped
      RBI
    end

    def test_print_methods_with_signature_params_mismatch
      rbi = parse_rbi(<<~RBI)
        sig { params(a: A).returns(R) }
        def foo(x); end
      RBI

      # RBI if we can't find the parameter in the signature, we translate it as untyped
      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: (untyped) -> R
      RBI
    end

    def test_print_methods_with_signature
      rbi = parse_rbi(<<~RBI)
        sig { params(a: A, b: B, c: C, d: D, e: E, f: F, block: T.proc.void).returns(R) }
        def foo(a, b = 42, *c, d:, e: 'bar', **f, &block); end
      RBI

      # RBI signature and parameters need to match
      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: (A a, ?B b, *C c, d: D, ?e: E, **F f) { -> void } -> R
      RBI
    end

    def test_print_methods_with_signatures
      rbi = parse_rbi(<<~RBI)
        sig { params(a: A, b: T.nilable(B)).returns(C) }
        sig { params(a: T.nilable(A), b: B).returns(C) }
        sig { params(a: A, b: B).returns(T.nilable(C)) }
        def foo(a, b); end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: (A a, B? b) -> C
               | (A? a, B b) -> C
               | (A a, B b) -> C?
      RBI
    end

    def test_print_methods_with_signature_with_modifiers
      rbi = parse_rbi(<<~RBI)
        sig { abstract.override.overridable.returns(void).checked(:never) }
        def foo; end
      RBI

      # Modifiers are ignored in RBS, but we generate comments for them
      # we ignore the checked level
      assert_equal(<<~RBI, rbi.rbs_string)
        # @abstract
        # @override
        # @overridable
        def foo: -> void
      RBI
    end

    def test_print_methods_with_signature_with_type_parameters
      rbi = parse_rbi(<<~RBI)
        sig { type_parameters(:U, :V).params(a: T.type_parameter(:U)).returns(T.type_parameter(:V)) }
        def foo(a); end
      RBI

      # To avoid conflict with existing constants, we prefix type parameters with `TYPE_`
      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: [TYPE_U, TYPE_V] (TYPE_U a) -> TYPE_V
      RBI
    end

    def test_print_methods_with_signatures_and_comments
      rbi = parse_rbi(<<~RBI)
        # This is a
        # multiline Comment
        def foo; end

        # This is a single line comment
        sig { returns(void) }
        def bar; end

        # This is a
        # multiline Comment
        sig { returns(A) }
        sig { returns(B) }
        def baz; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # This is a
        # multiline Comment
        def foo: (*untyped) -> untyped

        # This is a single line comment
        def bar: -> void

        # This is a
        # multiline Comment
        def baz: -> A
               | -> B
      RBI
    end

    def test_print_methods_with_blocks
      rbi = parse_rbi(<<~RBI)
        sig { params(block: T.proc.void).returns(R) }
        sig { params(block: T.untyped).returns(R) }
        sig { params(block: Proc).returns(R) }
        sig { params(block: T.nilable(Proc)).returns(R) }
        sig { params(block: NilClass).returns(R) }
        def foo(&block); end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        def foo: { -> void } -> R
               | ?{ (?) -> untyped } -> R
               | { (?) -> untyped } -> R
               | ?{ (?) -> untyped } -> R
               | -> R
      RBI
    end

    def test_print_mixins
      rbi = parse_rbi(<<~RBI)
        class Foo
          include A
          extend A, B
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        class Foo
          include A
          extend A, B
        end
      RBI
    end

    def test_print_visibility_labels
      rbi = parse_rbi(<<~RBI)
        public
        def m1; end
        protected
        def m2; end
        private
        def m3; end
      RBI

      # Protected is not supported by RBS, we just ignore it
      assert_equal(<<~RBI, rbi.rbs_string)
        public
        def m1: (*untyped) -> untyped
        def m2: (*untyped) -> untyped
        private
        def m3: (*untyped) -> untyped
      RBI
    end

    def test_print_sends
      rbi = parse_rbi(<<~RBI)
        class_attribute
        class_attribute :foo
        class_attribute :foo, :bar, instance_accessor: false, default: "Bar"
      RBI

      # RBS doesn't support any method sending, we just ignore them
      assert_empty(rbi.rbs_string)
    end

    def test_print_t_structs
      rbi = parse_rbi(<<~RBI)
        class Foo < T::Struct; end
        class Bar < T::Struct
          const :a, A
          const :b, B, default: "B.new"
          prop :c, C
          prop :d, D, default: "D.new"
        end

        class Baz < T::Struct
          const :a, A
          def foo; end
        end

        class Qux < T::Struct
          def foo; end
        end
      RBI

      # Const and props are not supported in RBS
      # instead, we generate attribute readers and writers
      # and a default constructor
      assert_equal(<<~RBI, rbi.rbs_string)
        class Foo
          def initialize: -> void
        end

        class Bar
          attr_reader a: A
          attr_reader b: B
          attr_accessor c: C
          attr_accessor d: D

          def initialize: (a: A, ?b: B, c: C, ?d: D) -> void
        end

        class Baz
          attr_reader a: A

          def initialize: (a: A) -> void

          def foo: (*untyped) -> untyped
        end

        class Qux
          def initialize: -> void

          def foo: (*untyped) -> untyped
        end
      RBI
    end

    def test_print_t_enums
      rbi = parse_rbi(<<~RBI)
        class Foo < T::Enum
          enums do
            A = new
            B = new
            C = new
          end

          def baz; end
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        class Foo
          A: Foo
          B: Foo
          C: Foo
          def baz: (*untyped) -> untyped
        end
      RBI
    end

    def test_print_sorbet_helpers
      rbi = parse_rbi(<<~RBI)
        class Foo
          foo!
          sealed!
          interface!
          mixes_in_class_methods A, B
          mixes_in_class_methods C
          requires_ancestor { D }
          requires_ancestor { E }
        end
      RBI

      # Helpers are not supported in RBS,
      # instead we generate comments for them
      assert_equal(<<~RBI, rbi.rbs_string)
        # @sealed
        # @interface
        # @mixes_in_class_methods A, B, C
        # @requires_ancestor D, E
        class Foo
        end
      RBI
    end

    def test_print_sorbet_type_members_and_templates
      rbi = parse_rbi(<<~RBI)
        class Foo
          A = type_member
          B = type_template
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        class Foo[A, B]
        end
      RBI
    end

    def test_print_nodes_with_comments
      rbi = parse_rbi(<<~RBI)
        # This is a single line comment
        module Foo
          # This is a
          # Multiline Comment
          A = type_member

          # This is a single line comment
          B = type_template
        end

        # This is a
        # Multiline Comment
        class Bar; end

        # This is a single line comment
        class << self; end

        # This is a
        # Multiline Comment
        Foo = 42

        # This is a single line comment
        include A

        # This is a
        # Multiline Comment
        extend A

        # This is a single line comment
        public

        # This is a single line comment
        private

        # This is a single line comment
        class Foo < T::Struct
          # This is a
          # Multiline Comment
          const :a, A

          # This is a single line comment
          prop :c, C
        end

        # This is a
        # Multiline Comment
        class Foo < T::Enum
          # This is a
          # Multiline Comment
          enums do
            # This is a
            # Multiline Comment
            A = new

            # This is a
            # Multiline Comment
            B = new
          end
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # This is a single line comment
        module Foo[A, B]
        end

        # This is a
        # Multiline Comment
        class Bar
        end

        # This is a single line comment
        class << self
        end

        # This is a
        # Multiline Comment
        Foo: untyped

        # This is a single line comment
        include A

        # This is a
        # Multiline Comment
        extend A

        # This is a single line comment
        public

        # This is a single line comment
        private

        # This is a single line comment
        class Foo
          # This is a
          # Multiline Comment
          attr_reader a: A

          # This is a single line comment
          attr_accessor c: C

          def initialize: (a: A, c: C) -> void
        end

        # This is a
        # Multiline Comment
        class Foo
          # This is a
          # Multiline Comment
          A: Foo

          # This is a
          # Multiline Comment
          B: Foo
        end
      RBI
    end

    def test_print_nodes_with_heredoc_comments
      rbi = parse_rbi(<<~RBI)
        # This
        # is
        # a
        # multiline
        # comment
        module Foo
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # This
        # is
        # a
        # multiline
        # comment
        module Foo
        end
      RBI
    end

    def test_print_tree_header_comments
      rbi = parse_rbi(<<~RBI)
        # typed: true
        # frozen_string_literal: false

        # Foo comment
        module Foo; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # typed: true
        # frozen_string_literal: false

        # Foo comment
        module Foo
        end
      RBI
    end

    def test_print_empty_comments
      rbi = parse_rbi(<<~RBI)
        # typed: true

        # Some intro comment
        # Some other comment
        #
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # typed: true

        # Some intro comment
        # Some other comment
        #
      RBI
    end

    def test_print_empty_trees_with_comments
      rbi = parse_rbi(<<~RBI)
        # foo
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # foo
      RBI
    end

    def test_print_params_inline_comments
      rbi = parse_rbi(<<~RBI)
        # comment
        def foo(
          a,        # comment
          b = 42,   # comment
          *c,       # comment
          d:,       # comment
          e: 'bar', # comment
          **f,      # comment
          &g        # comment
        ); end
      RBI

      # Comments are ignored when applied to RBS parameters
      assert_equal(<<~RBI, rbi.rbs_string)
        # comment
        def foo: (*untyped) -> untyped
      RBI
    end

    def test_print_blank_lines
      rbi = parse_rbi(<<~RBI)
        # comment 1

        # comment 2
        module Foo


          def foo; end



          class Bar
            # begin


            # middle


            # end
          end
        end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        # comment 1

        # comment 2
        module Foo
          def foo: (*untyped) -> untyped

          class Bar
            # begin
            # middle
            # end
          end
        end
      RBI
    end

    def test_print_new_lines_between_scopes
      rbi = parse_rbi(<<~RBI)
        class Bar
          include ModuleA
        end
        module ModuleA; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        class Bar
          include ModuleA
        end

        module ModuleA
        end
      RBI
    end

    def test_print_new_lines_between_methods_with_sigs
      rbi = parse_rbi(<<~RBI)
        def m1; end
        def m2; end

        sig { void }
        def m3; end

        def m4; end

        sig { void }
        sig { void }
        def m5; end

        sig { void }
        def m6; end

        def m7; end
        def m8; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string)
        def m1: (*untyped) -> untyped
        def m2: (*untyped) -> untyped

        def m3: -> void

        def m4: (*untyped) -> untyped

        def m5: -> void
              | -> void

        def m6: -> void

        def m7: (*untyped) -> untyped
        def m8: (*untyped) -> untyped
      RBI
    end

    def test_print_nodes_locations
      rbi = parse_rbi(<<~RBI)
        module S1; end
        class S2; end
        class << self; end
        C = 42
        extend E
        include I
        def m1; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string(print_locs: true))
        # -:1:0-1:14
        module S1
        end

        # -:2:0-2:13
        class S2
        end

        # -:3:0-3:18
        class << self
        end

        # -:4:0-4:6
        C: untyped
        # -:5:0-5:8
        extend E
        # -:6:0-6:9
        include I
        # -:7:0-7:11
        def m1: (*untyped) -> untyped
      RBI
    end

    def test_print_sigs_locations
      rbi = parse_rbi(<<~RBI)
        sig { void }
        sig { void }
        def foo; end
      RBI

      assert_equal(<<~RBI, rbi.rbs_string(print_locs: true))
        # -:3:0-3:12
        def foo: -> void # -:1:0-1:12
               | -> void # -:2:0-2:12
      RBI
    end

    private

    sig { params(rbs_string: String).returns(RBI::Node) }
    def parse_rbi(rbs_string)
      RBI::Parser.parse_string(rbs_string)
    end
  end
end
