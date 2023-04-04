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
    attr_accessor :loc

    sig { params(loc: T.nilable(Loc)).void }
    def initialize(loc: nil)
      @parent_tree = nil
      @loc = loc
    end

    sig { void }
    def detach
      tree = parent_tree
      return unless tree

      tree.nodes.delete(self)
      self.parent_tree = nil
    end

    sig { params(node: Node).void }
    def replace(node)
      tree = parent_tree
      raise unless tree

      index = tree.nodes.index(self)
      raise unless index

      tree.nodes[index] = node
      node.parent_tree = tree
      self.parent_tree = nil
    end

    sig { returns(T.nilable(Scope)) }
    def parent_scope
      parent = T.let(parent_tree, T.nilable(Tree))
      parent = parent.parent_tree until parent.is_a?(Scope) || parent.nil?
      parent
    end
  end

  class Comment < Node
    extend T::Sig

    sig { returns(String) }
    attr_accessor :text

    sig { params(text: String, loc: T.nilable(Loc)).void }
    def initialize(text, loc: nil)
      super(loc: loc)
      @text = text
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      return false unless other.is_a?(Comment)

      text == other.text
    end
  end

  # An arbitrary blank line that can be added both in trees and comments
  class BlankLine < Comment
    extend T::Sig

    sig { params(loc: T.nilable(Loc)).void }
    def initialize(loc: nil)
      super("", loc: loc)
    end
  end

  class NodeWithComments < Node
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(T::Array[Comment]) }
    attr_accessor :comments

    sig { params(loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(loc: nil, comments: [])
      super(loc: loc)
      @comments = comments
    end

    sig { returns(T::Array[String]) }
    def annotations
      comments
        .select { |comment| comment.text.start_with?("@") }
        .map { |comment| T.must(comment.text[1..]) }
    end
  end

  class Tree < NodeWithComments
    extend T::Sig

    sig { returns(T::Array[Node]) }
    attr_reader :nodes

    sig do
      params(
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Tree).void),
      ).void
    end
    def initialize(loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @nodes = T.let([], T::Array[Node])
      block&.call(self)
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

  class File
    extend T::Sig

    sig { returns(Tree) }
    attr_accessor :root

    sig { returns(T.nilable(String)) }
    attr_accessor :strictness

    sig { returns(T::Array[Comment]) }
    attr_accessor :comments

    sig do
      params(
        strictness: T.nilable(String),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(file: File).void),
      ).void
    end
    def initialize(strictness: nil, comments: [], &block)
      @root = T.let(Tree.new, Tree)
      @strictness = strictness
      @comments = comments
      block&.call(self)
    end

    sig { params(node: Node).void }
    def <<(node)
      @root << node
    end

    sig { returns(T::Boolean) }
    def empty?
      @root.empty?
    end
  end

  # Scopes

  class Scope < Tree
    extend T::Helpers

    abstract!

    sig { abstract.returns(String) }
    def fully_qualified_name; end

    sig { override.returns(String) }
    def to_s
      fully_qualified_name
    end
  end

  class Module < Scope
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Module).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments) {}
      @name = name
      block&.call(self)
    end

    sig { override.returns(String) }
    def fully_qualified_name
      return name if name.start_with?("::")

      "#{parent_scope&.fully_qualified_name}::#{name}"
    end
  end

  class Class < Scope
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig { returns(T.nilable(String)) }
    attr_accessor :superclass_name

    sig do
      params(
        name: String,
        superclass_name: T.nilable(String),
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Class).void),
      ).void
    end
    def initialize(name, superclass_name: nil, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments) {}
      @name = name
      @superclass_name = superclass_name
      block&.call(self)
    end

    sig { override.returns(String) }
    def fully_qualified_name
      return name if name.start_with?("::")

      "#{parent_scope&.fully_qualified_name}::#{name}"
    end
  end

  class SingletonClass < Scope
    extend T::Sig

    sig do
      params(
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: SingletonClass).void),
      ).void
    end
    def initialize(loc: nil, comments: [], &block)
      super(loc: loc, comments: comments) {}
      block&.call(self)
    end

    sig { override.returns(String) }
    def fully_qualified_name
      "#{parent_scope&.fully_qualified_name}::<self>"
    end
  end

  class Struct < Scope
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig { returns(T::Array[Symbol]) }
    attr_accessor :members

    sig { returns(T::Boolean) }
    attr_accessor :keyword_init

    sig do
      params(
        name: String,
        members: T::Array[Symbol],
        keyword_init: T::Boolean,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(struct: Struct).void),
      ).void
    end
    def initialize(name, members: [], keyword_init: false, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments) {}
      @name = name
      @members = members
      @keyword_init = keyword_init
      block&.call(self)
    end

    sig { override.returns(String) }
    def fully_qualified_name
      return name if name.start_with?("::")

      "#{parent_scope&.fully_qualified_name}::#{name}"
    end
  end

  # Consts

  class Const < NodeWithComments
    extend T::Sig

    sig { returns(String) }
    attr_reader :name, :value

    sig do
      params(
        name: String,
        value: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Const).void),
      ).void
    end
    def initialize(name, value, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @name = name
      @value = value
      block&.call(self)
    end

    sig { returns(String) }
    def fully_qualified_name
      return name if name.start_with?("::")

      "#{parent_scope&.fully_qualified_name}::#{name}"
    end

    sig { override.returns(String) }
    def to_s
      fully_qualified_name
    end
  end

  # Attributes

  class Attr < NodeWithComments
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(T::Array[Symbol]) }
    attr_accessor :names

    sig { returns(Visibility) }
    attr_accessor :visibility

    sig { returns(T::Array[Sig]) }
    attr_reader :sigs

    sig do
      params(
        name: Symbol,
        names: T::Array[Symbol],
        visibility: Visibility,
        sigs: T::Array[Sig],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).void
    end
    def initialize(name, names, visibility: Public.new, sigs: [], loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @names = T.let([name, *names], T::Array[Symbol])
      @visibility = visibility
      @sigs = sigs
    end

    sig { abstract.returns(T::Array[String]) }
    def fully_qualified_names; end
  end

  class AttrAccessor < Attr
    extend T::Sig

    sig do
      params(
        name: Symbol,
        names: Symbol,
        visibility: Visibility,
        sigs: T::Array[Sig],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: AttrAccessor).void),
      ).void
    end
    def initialize(name, *names, visibility: Public.new, sigs: [], loc: nil, comments: [], &block)
      super(name, names, loc: loc, visibility: visibility, sigs: sigs, comments: comments)
      block&.call(self)
    end

    sig { override.returns(T::Array[String]) }
    def fully_qualified_names
      parent_name = parent_scope&.fully_qualified_name
      names.flat_map { |name| ["#{parent_name}##{name}", "#{parent_name}##{name}="] }
    end

    sig { override.returns(String) }
    def to_s
      symbols = names.map { |name| ":#{name}" }.join(", ")
      "#{parent_scope&.fully_qualified_name}.attr_accessor(#{symbols})"
    end
  end

  class AttrReader < Attr
    extend T::Sig

    sig do
      params(
        name: Symbol,
        names: Symbol,
        visibility: Visibility,
        sigs: T::Array[Sig],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: AttrReader).void),
      ).void
    end
    def initialize(name, *names, visibility: Public.new, sigs: [], loc: nil, comments: [], &block)
      super(name, names, loc: loc, visibility: visibility, sigs: sigs, comments: comments)
      block&.call(self)
    end

    sig { override.returns(T::Array[String]) }
    def fully_qualified_names
      parent_name = parent_scope&.fully_qualified_name
      names.map { |name| "#{parent_name}##{name}" }
    end

    sig { override.returns(String) }
    def to_s
      symbols = names.map { |name| ":#{name}" }.join(", ")
      "#{parent_scope&.fully_qualified_name}.attr_reader(#{symbols})"
    end
  end

  class AttrWriter < Attr
    extend T::Sig

    sig do
      params(
        name: Symbol,
        names: Symbol,
        visibility: Visibility,
        sigs: T::Array[Sig],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: AttrWriter).void),
      ).void
    end
    def initialize(name, *names, visibility: Public.new, sigs: [], loc: nil, comments: [], &block)
      super(name, names, loc: loc, visibility: visibility, sigs: sigs, comments: comments)
      block&.call(self)
    end

    sig { override.returns(T::Array[String]) }
    def fully_qualified_names
      parent_name = parent_scope&.fully_qualified_name
      names.map { |name| "#{parent_name}##{name}=" }
    end

    sig { override.returns(String) }
    def to_s
      symbols = names.map { |name| ":#{name}" }.join(", ")
      "#{parent_scope&.fully_qualified_name}.attr_writer(#{symbols})"
    end
  end

  # Methods and args

  class Method < NodeWithComments
    extend T::Sig

    sig { returns(String) }
    attr_accessor :name

    sig { returns(T::Array[AbstractParam]) }
    attr_reader :params

    sig { returns(T::Boolean) }
    attr_accessor :is_singleton

    sig { returns(Visibility) }
    attr_accessor :visibility

    sig { returns(T::Array[Sig]) }
    attr_accessor :sigs

    sig do
      params(
        name: String,
        params: T::Array[AbstractParam],
        is_singleton: T::Boolean,
        visibility: Visibility,
        sigs: T::Array[Sig],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Method).void),
      ).void
    end
    def initialize(
      name,
      params: [],
      is_singleton: false,
      visibility: Public.new,
      sigs: [],
      loc: nil,
      comments: [],
      &block
    )
      super(loc: loc, comments: comments)
      @name = name
      @params = params
      @is_singleton = is_singleton
      @visibility = visibility
      @sigs = sigs
      block&.call(self)
    end

    sig { params(param: AbstractParam).void }
    def <<(param)
      @params << param
    end

    sig { returns(String) }
    def fully_qualified_name
      if is_singleton
        "#{parent_scope&.fully_qualified_name}::#{name}"
      else
        "#{parent_scope&.fully_qualified_name}##{name}"
      end
    end

    sig { override.returns(String) }
    def to_s
      "#{fully_qualified_name}(#{params.join(", ")})"
    end
  end

  class AbstractParam < NodeWithComments
    extend T::Helpers
    extend T::Sig

    abstract!

    sig { returns(String) }
    attr_reader :name

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).void
    end
    def initialize(name, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @name = name
    end

    sig { override.returns(String) }
    def to_s
      name
    end
  end

  class Param < AbstractParam
    extend T::Sig
  end

  class ReqParam < AbstractParam
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: ReqParam).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      ReqParam === other && name == other.name
    end
  end

  class OptParam < AbstractParam
    extend T::Sig

    sig { returns(String) }
    attr_reader :value

    sig do
      params(
        name: String,
        value: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: OptParam).void),
      ).void
    end
    def initialize(name, value, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      @value = value
      block&.call(self)
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      OptParam === other && name == other.name && value == other.value
    end
  end

  class RestParam < AbstractParam
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: RestParam).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "*#{name}"
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      RestParam === other && name == other.name
    end
  end

  class KwParam < AbstractParam
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: KwParam).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "#{name}:"
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      KwParam === other && name == other.name
    end
  end

  class KwOptParam < AbstractParam
    extend T::Sig

    sig { returns(String) }
    attr_reader :value

    sig do
      params(
        name: String,
        value: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: KwOptParam).void),
      ).void
    end
    def initialize(name, value, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      @value = value
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "#{name}:"
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      KwOptParam === other && name == other.name && value == other.value
    end
  end

  class KwRestParam < AbstractParam
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: KwRestParam).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "**#{name}:"
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      KwRestParam === other && name == other.name
    end
  end

  class BlockParam < AbstractParam
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: BlockParam).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "&#{name}"
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      BlockParam === other && name == other.name
    end
  end

  # Mixins

  class Mixin < NodeWithComments
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(T::Array[String]) }
    attr_accessor :names

    sig do
      params(
        name: String,
        names: T::Array[String],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).void
    end
    def initialize(name, names, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @names = T.let([name, *names], T::Array[String])
    end
  end

  class Include < Mixin
    extend T::Sig

    sig do
      params(
        name: String,
        names: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Include).void),
      ).void
    end
    def initialize(name, *names, loc: nil, comments: [], &block)
      super(name, names, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.include(#{names.join(", ")})"
    end
  end

  class Extend < Mixin
    extend T::Sig

    sig do
      params(
        name: String,
        names: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Extend).void),
      ).void
    end
    def initialize(name, *names, loc: nil, comments: [], &block)
      super(name, names, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.extend(#{names.join(", ")})"
    end
  end

  # Visibility

  class Visibility < NodeWithComments
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(Symbol) }
    attr_reader :visibility

    sig { params(visibility: Symbol, loc: T.nilable(Loc), comments: T::Array[Comment]).void }
    def initialize(visibility, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @visibility = visibility
    end

    sig { params(other: Visibility).returns(T::Boolean) }
    def ==(other)
      visibility == other.visibility
    end

    sig { returns(T::Boolean) }
    def public?
      visibility == :public
    end

    sig { returns(T::Boolean) }
    def protected?
      visibility == :protected
    end

    sig { returns(T::Boolean) }
    def private?
      visibility == :private
    end
  end

  class Public < Visibility
    extend T::Sig

    sig do
      params(
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Public).void),
      ).void
    end
    def initialize(loc: nil, comments: [], &block)
      super(:public, loc: loc, comments: comments)
      block&.call(self)
    end
  end

  class Protected < Visibility
    extend T::Sig

    sig do
      params(
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Protected).void),
      ).void
    end
    def initialize(loc: nil, comments: [], &block)
      super(:protected, loc: loc, comments: comments)
      block&.call(self)
    end
  end

  class Private < Visibility
    extend T::Sig

    sig do
      params(
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Private).void),
      ).void
    end
    def initialize(loc: nil, comments: [], &block)
      super(:private, loc: loc, comments: comments)
      block&.call(self)
    end
  end

  # Sends

  class Send < NodeWithComments
    extend T::Sig

    sig { returns(String) }
    attr_reader :method

    sig { returns(T::Array[Arg]) }
    attr_reader :args

    sig do
      params(
        method: String,
        args: T::Array[Arg],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Send).void),
      ).void
    end
    def initialize(method, args = [], loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @method = method
      @args = args
      block&.call(self)
    end

    sig { params(arg: Arg).void }
    def <<(arg)
      @args << arg
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      Send === other && method == other.method && args == other.args
    end

    sig { returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.#{method}(#{args.join(", ")})"
    end
  end

  class Arg < Node
    extend T::Sig

    sig { returns(String) }
    attr_reader :value

    sig do
      params(
        value: String,
        loc: T.nilable(Loc),
      ).void
    end
    def initialize(value, loc: nil)
      super(loc: loc)
      @value = value
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      Arg === other && value == other.value
    end

    sig { returns(String) }
    def to_s
      value
    end
  end

  class KwArg < Arg
    extend T::Sig

    sig { returns(String) }
    attr_reader :keyword

    sig do
      params(
        keyword: String,
        value: String,
        loc: T.nilable(Loc),
      ).void
    end
    def initialize(keyword, value, loc: nil)
      super(value, loc: loc)
      @keyword = keyword
    end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other)
      KwArg === other && value == other.value && keyword == other.keyword
    end

    sig { returns(String) }
    def to_s
      "#{keyword}: #{value}"
    end
  end

  # Sorbet's sigs

  class Sig < Node
    extend T::Sig

    sig { returns(T::Array[SigParam]) }
    attr_reader :params

    sig { returns(T.nilable(String)) }
    attr_accessor :return_type

    sig { returns(T::Boolean) }
    attr_accessor :is_abstract, :is_override, :is_overridable, :is_final

    sig { returns(T::Array[String]) }
    attr_reader :type_params

    sig { returns(T.nilable(Symbol)) }
    attr_accessor :checked

    sig do
      params(
        params: T::Array[SigParam],
        return_type: T.nilable(String),
        is_abstract: T::Boolean,
        is_override: T::Boolean,
        is_overridable: T::Boolean,
        is_final: T::Boolean,
        type_params: T::Array[String],
        checked: T.nilable(Symbol),
        loc: T.nilable(Loc),
        block: T.nilable(T.proc.params(node: Sig).void),
      ).void
    end
    def initialize(
      params: [],
      return_type: nil,
      is_abstract: false,
      is_override: false,
      is_overridable: false,
      is_final: false,
      type_params: [],
      checked: nil,
      loc: nil,
      &block
    )
      super(loc: loc)
      @params = params
      @return_type = return_type
      @is_abstract = is_abstract
      @is_override = is_override
      @is_overridable = is_overridable
      @is_final = is_final
      @type_params = type_params
      @checked = checked
      block&.call(self)
    end

    sig { params(param: SigParam).void }
    def <<(param)
      @params << param
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      return false unless other.is_a?(Sig)

      params == other.params && return_type == other.return_type && is_abstract == other.is_abstract &&
        is_override == other.is_override && is_overridable == other.is_overridable && is_final == other.is_final &&
        type_params == other.type_params && checked == other.checked
    end
  end

  class SigParam < NodeWithComments
    extend T::Sig

    sig { returns(String) }
    attr_reader :name, :type

    sig do
      params(
        name: String,
        type: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: SigParam).void),
      ).void
    end
    def initialize(name, type, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @name = name
      @type = type
      block&.call(self)
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      other.is_a?(SigParam) && name == other.name && type == other.type
    end
  end

  # Sorbet's T::Struct

  class TStruct < Class
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(klass: TStruct).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, superclass_name: "::T::Struct", loc: loc, comments: comments) {}
      block&.call(self)
    end
  end

  class TStructField < NodeWithComments
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(String) }
    attr_accessor :name, :type

    sig { returns(T.nilable(String)) }
    attr_accessor :default

    sig do
      params(
        name: String,
        type: String,
        default: T.nilable(String),
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).void
    end
    def initialize(name, type, default: nil, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @name = name
      @type = type
      @default = default
    end

    sig { abstract.returns(T::Array[String]) }
    def fully_qualified_names; end
  end

  class TStructConst < TStructField
    extend T::Sig

    sig do
      params(
        name: String,
        type: String,
        default: T.nilable(String),
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: TStructConst).void),
      ).void
    end
    def initialize(name, type, default: nil, loc: nil, comments: [], &block)
      super(name, type, default: default, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(T::Array[String]) }
    def fully_qualified_names
      parent_name = parent_scope&.fully_qualified_name
      ["#{parent_name}##{name}"]
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.const(:#{name})"
    end
  end

  class TStructProp < TStructField
    extend T::Sig

    sig do
      params(
        name: String,
        type: String,
        default: T.nilable(String),
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: TStructProp).void),
      ).void
    end
    def initialize(name, type, default: nil, loc: nil, comments: [], &block)
      super(name, type, default: default, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(T::Array[String]) }
    def fully_qualified_names
      parent_name = parent_scope&.fully_qualified_name
      ["#{parent_name}##{name}", "#{parent_name}##{name}="]
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.prop(:#{name})"
    end
  end

  # Sorbet's T::Enum

  class TEnum < Class
    extend T::Sig

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(klass: TEnum).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(name, superclass_name: "::T::Enum", loc: loc, comments: comments) {}
      block&.call(self)
    end
  end

  class TEnumBlock < NodeWithComments
    extend T::Sig

    sig { returns(T::Array[String]) }
    attr_reader :names

    sig do
      params(
        names: T::Array[String],
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: TEnumBlock).void),
      ).void
    end
    def initialize(names = [], loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @names = names
      block&.call(self)
    end

    sig { returns(T::Boolean) }
    def empty?
      names.empty?
    end

    sig { params(name: String).void }
    def <<(name)
      @names << name
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.enums"
    end
  end

  # Sorbet's misc.

  class Helper < NodeWithComments
    extend T::Helpers

    sig { returns(String) }
    attr_reader :name

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: Helper).void),
      ).void
    end
    def initialize(name, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @name = name
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.#{name}!"
    end
  end

  class TypeMember < NodeWithComments
    extend T::Sig

    sig { returns(String) }
    attr_reader :name, :value

    sig do
      params(
        name: String,
        value: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: TypeMember).void),
      ).void
    end
    def initialize(name, value, loc: nil, comments: [], &block)
      super(loc: loc, comments: comments)
      @name = name
      @value = value
      block&.call(self)
    end

    sig { returns(String) }
    def fully_qualified_name
      return name if name.start_with?("::")

      "#{parent_scope&.fully_qualified_name}::#{name}"
    end

    sig { override.returns(String) }
    def to_s
      fully_qualified_name
    end
  end

  class MixesInClassMethods < Mixin
    extend T::Sig

    sig do
      params(
        name: String,
        names: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
        block: T.nilable(T.proc.params(node: MixesInClassMethods).void),
      ).void
    end
    def initialize(name, *names, loc: nil, comments: [], &block)
      super(name, names, loc: loc, comments: comments)
      block&.call(self)
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.mixes_in_class_methods(#{names.join(", ")})"
    end
  end

  class RequiresAncestor < NodeWithComments
    extend T::Sig

    sig { returns(String) }
    attr_reader :name

    sig do
      params(
        name: String,
        loc: T.nilable(Loc),
        comments: T::Array[Comment],
      ).void
    end
    def initialize(name, loc: nil, comments: [])
      super(loc: loc, comments: comments)
      @name = name
    end

    sig { override.returns(String) }
    def to_s
      "#{parent_scope&.fully_qualified_name}.requires_ancestor(#{name})"
    end
  end
end
