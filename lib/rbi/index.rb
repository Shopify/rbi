# typed: strict
# frozen_string_literal: true

module RBI
  class Index < Visitor
    extend T::Sig
    include T::Enumerable

    class << self
      extend T::Sig

      #: (*Node node) -> Index
      def index(*node)
        index = Index.new
        index.visit_all(node)
        index
      end
    end

    #: -> void
    def initialize
      super
      @index = T.let({}, T::Hash[String, T::Array[Node]])
    end

    #: -> Array[String]
    def keys
      @index.keys
    end

    #: (String id) -> Array[Node]
    def [](id)
      @index[id] ||= []
    end

    #: (*Node nodes) -> void
    def index(*nodes)
      nodes.each { |node| visit(node) }
    end

    # @override
    #: (Node? node) -> void
    def visit(node)
      return unless node

      case node
      when Scope
        index_node(node)
        visit_all(node.nodes)
      when Tree
        visit_all(node.nodes)
      when Indexable
        index_node(node)
      end
    end

    private

    #: ((Indexable & Node) node) -> void
    def index_node(node)
      node.index_ids.each { |id| self[id] << node }
    end
  end

  class Tree
    extend T::Sig

    #: -> Index
    def index
      Index.index(self)
    end
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
    # @abstract
    #: -> Array[String]
    def index_ids; end
  end

  class Scope
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [fully_qualified_name]
    end
  end

  class Const
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [fully_qualified_name]
    end
  end

  class Attr
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      fully_qualified_names
    end
  end

  class Method
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [fully_qualified_name]
    end
  end

  class Include
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      names.map { |name| "#{parent_scope&.fully_qualified_name}.include(#{name})" }
    end
  end

  class Extend
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      names.map { |name| "#{parent_scope&.fully_qualified_name}.extend(#{name})" }
    end
  end

  class MixesInClassMethods
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      names.map { |name| "#{parent_scope&.fully_qualified_name}.mixes_in_class_method(#{name})" }
    end
  end

  class RequiresAncestor
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [to_s]
    end
  end

  class Helper
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [to_s]
    end
  end

  class TypeMember
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [to_s]
    end
  end

  class Send
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      ["#{parent_scope&.fully_qualified_name}.#{method}"]
    end
  end

  class TStructConst
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      fully_qualified_names
    end
  end

  class TStructProp
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      fully_qualified_names
    end
  end

  class TEnumBlock
    extend T::Sig
    include Indexable

    # @override
    #: -> Array[String]
    def index_ids
      [to_s]
    end
  end
end
