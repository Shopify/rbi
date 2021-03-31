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

    sig { returns(T::Boolean) }
    def empty?
      nodes.empty?
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

  class Const < Node
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig { params(name: String).void }
    def initialize(name)
      super()
      @name = name
    end
  end

  class Method < Node
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig { returns(T::Array[Param]) }
    attr_reader :params

    sig { returns(T::Boolean) }
    attr_accessor :is_singleton

    sig do
      params(
        name: String,
        params: T::Array[Param],
        is_singleton: T::Boolean
      ).void
    end
    def initialize(name, params: [], is_singleton: false)
      super()
      @name = name
      @params = params
      @is_singleton = is_singleton
    end

    sig { returns(String) }
    def to_s
      name
    end
  end

  class Param < Node
    extend T::Sig

    sig { returns(String) }
    attr_reader :name

    sig { returns(T::Boolean) }
    attr_accessor :is_optional, :is_keyword, :is_rest, :is_block

    sig do
      params(
        name: String,
        is_optional: T::Boolean,
        is_keyword: T::Boolean,
        is_rest: T::Boolean,
        is_block: T::Boolean
      ).void
    end
    def initialize(name, is_optional: false, is_keyword: false, is_rest: false, is_block: false)
      super()
      @name = name
      @is_optional = is_optional
      @is_keyword = is_keyword
      @is_rest = is_rest
      @is_block = is_block
    end

    sig { returns(String) }
    def to_s
      name
    end
  end

  # Sends

  class Send < Node
    extend T::Sig

    sig { returns(::Symbol) }
    attr_reader :method

    sig { returns(T::Array[String]) }
    attr_reader :args

    sig { params(method: ::Symbol, args: T::Array[String]).void }
    def initialize(method, args: [])
      super()
      @method = method
      @args = args
    end
  end
end
