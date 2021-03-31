# typed: strict
# frozen_string_literal: true

module RBI
  extend T::Sig

  class Index < Visitor
    extend T::Sig
    include T::Enumerable

    sig { params(trees: T::Array[Tree]).returns(Index) }
    def self.index(trees)
      index = Index.new
      trees.each { |tree| index.visit(tree) }
      index
    end

    sig { void }
    def initialize
      super()
      @index = T.let({}, T::Hash[String, T::Array[T.all(Indexable, Node)]])
    end

    sig { override.params(node: T.nilable(Node)).void }
    def visit(node)
      case node
      when Module, Class
        index(node)
        visit_all(node.nodes)
      when Method, Const
        index(node)
      when Tree
        visit_all(node.nodes)
      end
    end

    sig { returns(T::Boolean) }
    def empty?
      @index.empty?
    end

    sig { returns(T::Array[String]) }
    def keys
      @index.keys
    end

    sig { params(block: T.proc.params(pair: [String, T::Array[T.all(Node, Indexable)]]).void).void }
    def each(&block)
      @index.each(&block)
    end

    sig { params(out: T.any(IO, StringIO)).void }
    def pretty_print(out: $stdout)
      @index.keys.sort.each do |name|
        nodes = T.must(@index[name])
        out.puts "#{name}: #{nodes.join(", ")}"
      end
    end

    private

    sig { params(node: T.all(Indexable, Node)).void }
    def index(node)
      name = node.index_key
      arr = @index[name] ||= []
      arr << node
    end
  end

  module Indexable
    extend T::Sig
    extend T::Helpers

    interface!

    sig { abstract.returns(String) }
    def index_key; end
  end

  class Scope
    include Indexable

    sig { override.returns(String) }
    def index_key
      qualified_name
    end
  end

  class Method
    include Indexable

    sig { override.returns(String) }
    def index_key
      qualified_name
    end
  end

  class Const
    include Indexable

    sig { override.returns(String) }
    def index_key
      qualified_name
    end
  end
end
