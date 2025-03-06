# typed: strict
# frozen_string_literal: true

module RBI
  class Index < Visitor
    include T::Enumerable

    class << self
      sig { params(node: Node).returns(Index) }
      def index(*node); end
    end

    sig { void }
    def initialize; end

    sig { returns(Array) }
    def keys; end

    sig { params(id: String).returns(Array) }
    def [](id); end

    sig { params(nodes: Node).void }
    def index(*nodes); end

    # @override
    sig { params(node: T.nilable(Node)).void }
    def visit(node); end

    private

    sig { params(node: T.all(Indexable, Node)).void }
    def index_node(node); end
  end

  class Tree
    sig { returns(Index) }
    def index; end
  end

  # A Node that can be referred to by a unique ID inside an index
  module Indexable
    extend T::Sig
    extend T::Helpers
    interface!

    # Unique IDs that refer to this node.
    #
    # Some nodes can have multiple ids, for example an attribute accessor matches the ID of the
    # getter and the setter.
    sig { abstract.returns(T::Array[String]) }
    def index_ids; end
  end

  class Scope
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Const
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Attr
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Method
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Include
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Extend
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class MixesInClassMethods
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class RequiresAncestor
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Helper
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class TypeMember
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class Send
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class TStructConst
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class TStructProp
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end

  class TEnumBlock
    include Indexable

    # @override
    sig { returns(Array) }
    def index_ids; end
  end
end
