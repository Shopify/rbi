# typed: strict
# frozen_string_literal: true

module RBI
  class Node
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(T.nilable(Tree)) }
    attr_accessor :parent_tree

    sig { returns(T.nilable(Loc)) }
    attr_reader :loc

    sig { returns(T::Array[Comment]) }
    attr_accessor :comments

    sig { params(loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(loc: nil, comments: [])
      @parent_tree = nil
      @loc = loc
      @comments = comments
    end

    sig { returns(T.nilable(Scope)) }
    def parent_scope
      parent_tree = T.let(self.parent_tree, T.nilable(Tree))
      until parent_tree.nil?
        return parent_tree if parent_tree.is_a?(Scope)
        parent_tree = parent_tree.parent_tree
      end
      nil
    end
  end

  class Comment < Node
    extend T::Helpers

    sig { returns(String) }
    attr_accessor :text

    sig { params(text: String, loc: T.nilable(Loc)).void }
    def initialize(text, loc: nil)
      super(loc: loc)
      @text = text
    end
  end

  class Tree < Node
    extend T::Sig

    sig { returns(T::Array[Node]) }
    attr_reader :nodes

    sig { params(loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(loc: nil, comments: [])
      super
      @nodes = T.let([], T::Array[Node])
    end

    sig { params(node: Node).void }
    def <<(node)
      node.parent_tree = self
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

    sig { params(name: String, loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(name, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @name = name
    end

    sig { returns(String) }
    def qualified_name
      return name if name.start_with?("::")
      scope = parent_scope
      return "::#{name}" unless scope
      "#{scope.qualified_name}::#{name}"
    end

    sig { returns(String) }
    def to_s
      name
    end
  end

  class Module < Scope
    extend T::Sig

    sig { params(name: String, loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(name, loc: nil, comments: [])
      super
    end
  end

  class Class < Scope
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :superclass_name

    sig do
      params(
        name: String,
        superclass_name: T.nilable(String),
        loc: T.nilable(Loc),
        comments: T::Array[Comment]
      ).void
    end
    def initialize(name, superclass_name: nil, loc: nil, comments: [])
      super(name, loc: loc, comments: comments)
      @superclass_name = superclass_name
    end
  end

  class SClass < Scope
    extend T::Sig

    sig { params(loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(loc: nil, comments: [])
      super("", loc: loc, comments: comments)
    end
  end

  class Const < Node
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig { params(name: String, loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(name, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @name = name
    end

    sig { returns(String) }
    def qualified_name
      return name if name.start_with?("::")
      scope = parent_scope
      return "::#{name}" unless scope
      "#{scope.qualified_name}::#{name}"
    end

    sig { returns(String) }
    def to_s
      name
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
        is_singleton: T::Boolean,
        loc: T.nilable(Loc),
        comments: T::Array[Comment]
      ).void
    end
    def initialize(name, params: [], is_singleton: false, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @name = name
      @params = params
      @is_singleton = is_singleton
    end

    sig { returns(String) }
    def qualified_name
      scope = parent_scope
      sep = is_singleton ? "::" : "#"
      str = "#{sep}#{name}"
      return str unless scope
      "#{scope.qualified_name}#{str}"
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
        is_block: T::Boolean,
        loc: T.nilable(Loc),
        comments: T::Array[Comment]
      ).void
    end
    def initialize(name, is_optional: false, is_keyword: false, is_rest: false, is_block: false, loc: nil, comments: [])
      super(loc: loc, comments: comments)
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

    sig do
      params(
        method: ::Symbol,
        args: T::Array[String],
        loc: T.nilable(Loc),
        comments: T::Array[Comment]
      ).void
    end
    def initialize(method, args: [], loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @method = method
      @args = args
    end

    sig { returns(String) }
    def to_s
      "#{method} #{args.join(", ")}"
    end
  end
end
