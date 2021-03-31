# typed: strict
# frozen_string_literal: true

module RBI
  class Node
    extend T::Sig
    extend T::Helpers

    abstract!
  end

  class Tree < Node
    extend T::Sig

    sig { returns(T::Array[Node]) }
    attr_reader :nodes

    sig { void }
    def initialize
      @nodes = T.let([], T::Array[Node])
    end

    sig { params(node: Node).void }
    def <<(node)
      @nodes << node
    end
  end

  class Scope < Tree
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(String) }
    attr_accessor :name

    sig { params(name: String).void }
    def initialize(name)
      super()
      @name = name
    end

    sig { returns(String) }
    def to_s
      name
    end
  end

  class Module < Scope
    extend T::Sig

    sig { params(name: String).void }
    def initialize(name)
      super(name)
    end
  end
end
