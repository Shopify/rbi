# typed: strict
# frozen_string_literal: true

module RBI
  extend T::Sig

  class Index < Visitor
    extend T::Sig
    include T::Enumerable

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

    sig { params(out: T.any(IO, StringIO)).void }
    def print_index(out: $stdout)
      @index.keys.sort.each do |name|
        nodes = T.must(@index[name])
        out.puts "#{name}: #{nodes.join(", ")}"
      end
    end

    sig { returns(T::Boolean) }
    def empty?
      @index.empty?
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