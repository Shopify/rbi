# typed: true
# frozen_string_literal: true

require "test_helper"

module RBI
  class IndexTest < Minitest::Test
    include TestHelper
    extend T::Sig

    def test_index_empty_trees
      tree = Tree.new
      index_string = index_string(tree.index)
      assert_empty(index_string)
    end

    def test_index_scopes_and_consts
      tree = parse_rbi(<<~RBI)
        class A
          module B
            module ::C; end
          end
        end
        module B
          class ::A; end
          class << self; end
        end
        A::B = 10
      RBI

      index_string = index_string(tree.index)
      assert_equal(<<~IDX, index_string)
        ::A: -:1:0-5:3, -:7:2-7:16
        ::A::B: -:2:2-4:5, -:10:0-10:9
        ::B: -:6:0-9:3
        ::B::<self>: -:8:2-8:20
        ::C: -:3:4-3:19
      IDX
    end

    def test_index_properties
      tree = parse_rbi(<<~RBI)
        class A
          attr_reader :a, :b
          attr_writer :a, :b
          attr_accessor :c
          def foo(a); end
          include A, B
          extend T::Sig
          abstract!
          foo :bar, baz: "baz"
        end
      RBI

      index_string = index_string(tree.index)
      assert_equal(<<~IDX, index_string)
        ::A: -:1:0-10:3
        ::A#a: -:2:2-2:20
        ::A#a=: -:3:2-3:20
        ::A#b: -:2:2-2:20
        ::A#b=: -:3:2-3:20
        ::A#c: -:4:2-4:18
        ::A#c=: -:4:2-4:18
        ::A#foo: -:5:2-5:17
        ::A.abstract!: -:8:2-8:11
        ::A.extend(T::Sig): -:7:2-7:15
        ::A.foo: -:9:2-9:22
        ::A.include(A): -:6:2-6:14
        ::A.include(B): -:6:2-6:14
      IDX
    end

    def test_index_sorbet_constructs
      tree = parse_rbi(<<~RBI)
        class A < T::Struct
          const :a, Integer
          prop :b, String
        end

        class B < T::Enum
          enums do
            B1 = new
            B2 = new
          end
        end

        mixes_in_class_methods A
        requires_ancestor { A }
        C = type_member
        D = type_template
      RBI

      index_string = index_string(tree.index)
      assert_equal(<<~IDX, index_string)
        .mixes_in_class_method(A): -:13:0-13:24
        .requires_ancestor(A): -:14:0-14:23
        ::A: -:1:0-4:3
        ::A#a: -:2:2-2:19
        ::A#b: -:3:2-3:17
        ::A#b=: -:3:2-3:17
        ::B: -:6:0-11:3
        ::B.enums: -:7:2-10:5
        ::B.enums::B1: -:8:4-8:12
        ::B.enums::B2: -:9:4-9:12
        ::C: -:15:0-15:15
        ::D: -:16:0-16:17
      IDX
    end

    def test_index_multiple_trees
      tree1 = parse_rbi(<<~RBI)
        class A
          module B
            module ::C; end
          end
        end
      RBI

      tree2 = parse_rbi(<<~RBI)
        class A
          module B
            module ::C; end
          end
        end
      RBI

      index = Index.index(tree1, tree2)
      index_string = index_string(index)
      assert_equal(<<~IDX, index_string)
        ::A: -:1:0-5:3, -:1:0-5:3
        ::A::B: -:2:2-4:5, -:2:2-4:5
        ::C: -:3:4-3:19, -:3:4-3:19
      IDX
    end

    sig { params(index: Index).returns(String) }
    def index_string(index)
      io = StringIO.new
      index.keys.sort.each do |key|
        io.puts "#{key}: #{index[key].map(&:loc).join(", ")}"
      end
      io.string
    end
  end
end
