# typed: strict
# frozen_string_literal: true

# Scopes

# Consts

# Attributes

# Methods and args

# Mixins

# Visibility

# Sends

# Sorbet's sigs

# Sorbet's T::Struct

# Sorbet's T::Enum

# Sorbet's misc.

module RBI
  class ReplaceNodeError < Error; end

  class Node
    extend T::Helpers
    abstract!

    sig { returns(T.nilable(Tree)) }
    attr_accessor :parent_tree

    sig { returns(T.nilable(Loc)) }
    attr_accessor :loc

    sig { params(loc: T.nilable(Loc)).void }
    def initialize(loc: nil); end

    sig { void }
    def detach; end

    sig { params(node: Node).void }
    def replace(node); end

    sig { returns(T.nilable(Scope)) }
    def parent_scope; end
  end

  class Comment < Node
    sig { returns(String) }
    attr_accessor :text

    sig { params(text: String, loc: T.nilable(Loc)).void }
    def initialize(text, loc: nil); end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other); end
  end

  # An arbitrary blank line that can be added both in trees and comments
  class BlankLine < Comment
    sig { params(loc: T.nilable(Loc)).void }
    def initialize(loc: nil); end
  end

  # A comment representing a RBS type prefixed with `#:`
  class RBSComment < Comment
    sig { params(other: Object).returns(T::Boolean) }
    def ==(other); end
  end

  class NodeWithComments < Node
    extend T::Helpers
    abstract!

    sig { returns(Array[Comment]) }
    attr_accessor :comments

    sig { params(loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(loc: nil, comments: []); end

    sig { returns(Array[String]) }
    def annotations; end
  end

  class Tree < NodeWithComments
    sig { returns(Array[Node]) }
    attr_reader :nodes

    sig { params(loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Tree).void)).void }
    def initialize(loc: nil, comments: [], &block); end

    sig { params(node: Node).void }
    def <<(node); end

    sig { returns(T::Boolean) }
    def empty?; end
  end

  class File
    sig { returns(Tree) }
    attr_accessor :root

    sig { returns(T.nilable(String)) }
    attr_accessor :strictness

    sig { returns(Array[Comment]) }
    attr_accessor :comments

    sig { params(strictness: T.nilable(String), comments: Array[Comment], block: T.nilable(T.proc.params(file: File).void)).void }
    def initialize(strictness: nil, comments: [], &block); end

    sig { params(node: Node).void }
    def <<(node); end

    sig { returns(T::Boolean) }
    def empty?; end
  end

  class Scope < Tree
    extend T::Sig
    extend T::Helpers
    abstract!

    sig { abstract.returns(String) }
    def fully_qualified_name; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Module < Scope
    sig { returns(String) }
    attr_accessor :name

    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Module).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def fully_qualified_name; end
  end

  class Class < Scope
    sig { returns(String) }
    attr_accessor :name

    sig { returns(T.nilable(String)) }
    attr_accessor :superclass_name

    sig { params(name: String, superclass_name: T.nilable(String), loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Class).void)).void }
    def initialize(name, superclass_name: nil, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def fully_qualified_name; end
  end

  class SingletonClass < Scope
    sig { params(loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: SingletonClass).void)).void }
    def initialize(loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def fully_qualified_name; end
  end

  class Struct < Scope
    sig { returns(String) }
    attr_accessor :name

    sig { returns(Array[Symbol]) }
    attr_accessor :members

    sig { returns(T::Boolean) }
    attr_accessor :keyword_init

    sig { params(name: String, members: Array[Symbol], keyword_init: T::Boolean, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(struct: Struct).void)).void }
    def initialize(name, members: [], keyword_init: false, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def fully_qualified_name; end
  end

  class Const < NodeWithComments
    sig { returns(String) }
    attr_reader :name, :value

    sig { params(name: String, value: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Const).void)).void }
    def initialize(name, value, loc: nil, comments: [], &block); end

    sig { returns(String) }
    def fully_qualified_name; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Attr < NodeWithComments
    extend T::Sig
    extend T::Helpers
    abstract!

    sig { returns(Array[Symbol]) }
    attr_reader :names

    sig { returns(Visibility) }
    attr_accessor :visibility

    sig { returns(Array[Sig]) }
    attr_reader :sigs

    sig { params(name: Symbol, names: Array[Symbol], visibility: Visibility, sigs: Array[Sig], loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(name, names, visibility: Public.new, sigs: [], loc: nil, comments: []); end

    sig { abstract.returns(T::Array[String]) }
    def fully_qualified_names; end
  end

  class AttrAccessor < Attr
    sig { params(name: Symbol, names: Symbol, visibility: Visibility, sigs: Array[Sig], loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: AttrAccessor).void)).void }
    def initialize(name, *names, visibility: Public.new, sigs: [], loc: nil, comments: [], &block); end

    # @override
    sig { returns(Array[String]) }
    def fully_qualified_names; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class AttrReader < Attr
    sig { params(name: Symbol, names: Symbol, visibility: Visibility, sigs: Array[Sig], loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: AttrReader).void)).void }
    def initialize(name, *names, visibility: Public.new, sigs: [], loc: nil, comments: [], &block); end

    # @override
    sig { returns(Array[String]) }
    def fully_qualified_names; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class AttrWriter < Attr
    sig { params(name: Symbol, names: Symbol, visibility: Visibility, sigs: Array[Sig], loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: AttrWriter).void)).void }
    def initialize(name, *names, visibility: Public.new, sigs: [], loc: nil, comments: [], &block); end

    # @override
    sig { returns(Array[String]) }
    def fully_qualified_names; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Method < NodeWithComments
    sig { returns(String) }
    attr_accessor :name

    sig { returns(Array[Param]) }
    attr_reader :params

    sig { returns(T::Boolean) }
    attr_accessor :is_singleton

    sig { returns(Visibility) }
    attr_accessor :visibility

    sig { returns(Array[Sig]) }
    attr_accessor :sigs

    sig { params(name: String, params: Array[Param], is_singleton: T::Boolean, visibility: Visibility, sigs: Array[Sig], loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Method).void)).void }
    def initialize(name, params: [], is_singleton: false, visibility: Public.new, sigs: [], loc: nil, comments: [], &block); end

    sig { params(param: Param).void }
    def <<(param); end

    sig { params(name: String).void }
    def add_param(name); end

    sig { params(name: String, default_value: String).void }
    def add_opt_param(name, default_value); end

    sig { params(name: String).void }
    def add_rest_param(name); end

    sig { params(name: String).void }
    def add_kw_param(name); end

    sig { params(name: String, default_value: String).void }
    def add_kw_opt_param(name, default_value); end

    sig { params(name: String).void }
    def add_kw_rest_param(name); end

    sig { params(name: String).void }
    def add_block_param(name); end

    sig { params(params: Array[SigParam], return_type: T.any(String, Type), is_abstract: T::Boolean, is_override: T::Boolean, is_overridable: T::Boolean, is_final: T::Boolean, type_params: Array[String], checked: T.nilable(Symbol), block: T.nilable(T.proc.params(node: Sig).void)).void }
    def add_sig(params: [], return_type: "void", is_abstract: false, is_override: false, is_overridable: false, is_final: false, type_params: [], checked: nil, &block); end

    sig { returns(String) }
    def fully_qualified_name; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Param < NodeWithComments
    extend T::Helpers
    abstract!

    sig { returns(String) }
    attr_reader :name

    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(name, loc: nil, comments: []); end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class ReqParam < Param
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: ReqParam).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class OptParam < Param
    sig { returns(String) }
    attr_reader :value

    sig { params(name: String, value: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: OptParam).void)).void }
    def initialize(name, value, loc: nil, comments: [], &block); end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class RestParam < Param
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: RestParam).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class KwParam < Param
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: KwParam).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class KwOptParam < Param
    sig { returns(String) }
    attr_reader :value

    sig { params(name: String, value: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: KwOptParam).void)).void }
    def initialize(name, value, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class KwRestParam < Param
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: KwRestParam).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class BlockParam < Param
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: BlockParam).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end
  end

  class Mixin < NodeWithComments
    extend T::Helpers
    abstract!

    sig { returns(Array[String]) }
    attr_reader :names

    sig { params(name: String, names: Array[String], loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(name, names, loc: nil, comments: []); end
  end

  class Include < Mixin
    sig { params(name: String, names: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Include).void)).void }
    def initialize(name, *names, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Extend < Mixin
    sig { params(name: String, names: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Extend).void)).void }
    def initialize(name, *names, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Visibility < NodeWithComments
    extend T::Helpers
    abstract!

    sig { returns(Symbol) }
    attr_reader :visibility

    sig { params(visibility: Symbol, loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(visibility, loc: nil, comments: []); end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end

    sig { returns(T::Boolean) }
    def public?; end

    sig { returns(T::Boolean) }
    def protected?; end

    sig { returns(T::Boolean) }
    def private?; end
  end

  class Public < Visibility
    sig { params(loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Public).void)).void }
    def initialize(loc: nil, comments: [], &block); end
  end

  class Protected < Visibility
    sig { params(loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Protected).void)).void }
    def initialize(loc: nil, comments: [], &block); end
  end

  class Private < Visibility
    sig { params(loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Private).void)).void }
    def initialize(loc: nil, comments: [], &block); end
  end

  class Send < NodeWithComments
    sig { returns(String) }
    attr_reader :method

    sig { returns(Array[Arg]) }
    attr_reader :args

    sig { params(method: String, args: Array[Arg], loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Send).void)).void }
    def initialize(method, args = [], loc: nil, comments: [], &block); end

    sig { params(arg: Arg).void }
    def <<(arg); end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end

    sig { returns(String) }
    def to_s; end
  end

  class Arg < Node
    sig { returns(String) }
    attr_reader :value

    sig { params(value: String, loc: T.nilable(Loc)).void }
    def initialize(value, loc: nil); end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end

    sig { returns(String) }
    def to_s; end
  end

  class KwArg < Arg
    sig { returns(String) }
    attr_reader :keyword

    sig { params(keyword: String, value: String, loc: T.nilable(Loc)).void }
    def initialize(keyword, value, loc: nil); end

    sig { params(other: T.nilable(Object)).returns(T::Boolean) }
    def ==(other); end

    sig { returns(String) }
    def to_s; end
  end

  class Sig < NodeWithComments
    sig { returns(Array[SigParam]) }
    attr_reader :params

    sig { returns(T.any(Type, String)) }
    attr_accessor :return_type

    sig { returns(T::Boolean) }
    attr_accessor :is_abstract, :is_override, :is_overridable, :is_final, :allow_incompatible_override

    sig { returns(Array[String]) }
    attr_reader :type_params

    sig { returns(T.nilable(Symbol)) }
    attr_accessor :checked

    sig { params(params: Array[SigParam], return_type: T.any(Type, String), is_abstract: T::Boolean, is_override: T::Boolean, is_overridable: T::Boolean, is_final: T::Boolean, allow_incompatible_override: T::Boolean, type_params: Array[String], checked: T.nilable(Symbol), loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Sig).void)).void }
    def initialize(params: [], return_type: "void", is_abstract: false, is_override: false, is_overridable: false, is_final: false, allow_incompatible_override: false, type_params: [], checked: nil, loc: nil, comments: [], &block); end

    sig { params(param: SigParam).void }
    def <<(param); end

    sig { params(name: String, type: T.any(Type, String)).void }
    def add_param(name, type); end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other); end
  end

  class SigParam < NodeWithComments
    sig { returns(String) }
    attr_reader :name

    sig { returns(T.any(Type, String)) }
    attr_reader :type

    sig { params(name: String, type: T.any(Type, String), loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: SigParam).void)).void }
    def initialize(name, type, loc: nil, comments: [], &block); end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other); end
  end

  class TStruct < Class
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(klass: TStruct).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end
  end

  class TStructField < NodeWithComments
    extend T::Sig
    extend T::Helpers
    abstract!

    sig { returns(String) }
    attr_accessor :name

    sig { returns(T.any(Type, String)) }
    attr_accessor :type

    sig { returns(T.nilable(String)) }
    attr_accessor :default

    sig { params(name: String, type: T.any(Type, String), default: T.nilable(String), loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(name, type, default: nil, loc: nil, comments: []); end

    sig { abstract.returns(T::Array[String]) }
    def fully_qualified_names; end
  end

  class TStructConst < TStructField
    sig { params(name: String, type: T.any(Type, String), default: T.nilable(String), loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: TStructConst).void)).void }
    def initialize(name, type, default: nil, loc: nil, comments: [], &block); end

    # @override
    sig { returns(Array[String]) }
    def fully_qualified_names; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class TStructProp < TStructField
    sig { params(name: String, type: T.any(Type, String), default: T.nilable(String), loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: TStructProp).void)).void }
    def initialize(name, type, default: nil, loc: nil, comments: [], &block); end

    # @override
    sig { returns(Array[String]) }
    def fully_qualified_names; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class TEnum < Class
    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(klass: TEnum).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end
  end

  class TEnumBlock < Scope
    sig { params(loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: TEnumBlock).void)).void }
    def initialize(loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def fully_qualified_name; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class Helper < NodeWithComments
    sig { returns(String) }
    attr_reader :name

    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: Helper).void)).void }
    def initialize(name, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class TypeMember < NodeWithComments
    sig { returns(String) }
    attr_reader :name, :value

    sig { params(name: String, value: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: TypeMember).void)).void }
    def initialize(name, value, loc: nil, comments: [], &block); end

    sig { returns(String) }
    def fully_qualified_name; end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class MixesInClassMethods < Mixin
    sig { params(name: String, names: String, loc: T.nilable(Loc), comments: Array[Comment], block: T.nilable(T.proc.params(node: MixesInClassMethods).void)).void }
    def initialize(name, *names, loc: nil, comments: [], &block); end

    # @override
    sig { returns(String) }
    def to_s; end
  end

  class RequiresAncestor < NodeWithComments
    sig { returns(String) }
    attr_reader :name

    sig { params(name: String, loc: T.nilable(Loc), comments: Array[Comment]).void }
    def initialize(name, loc: nil, comments: []); end

    # @override
    sig { returns(String) }
    def to_s; end
  end
end
