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

  class Class < Scope
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :superclass_name

    sig { params(name: String, superclass_name: T.nilable(String)).void }
    def initialize(name, superclass_name: nil)
      super(name)
      @superclass_name = superclass_name
    end
  end

  class SClass < Scope
    extend T::Sig

    sig { void }
    def initialize
      super("")
    end
  end
end
