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
      @index = T.let({}, T::Hash[String, T::Array[Node]])
    end

    sig { override.params(node: T.nilable(Node)).void }
    def visit(node)
      case node
      when Module, Class
        index(node)
        visit_all(node.nodes)
      when Method, Const, Send
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

    sig { params(block: T.proc.params(pair: [String, T::Array[Node]]).void).void }
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

    ATTR_REGEX = /^attr_(.*)/

    sig { params(node: Node).void }
    def index(node)
      case node
      when Scope, Method, Const
        name = node.qualified_name
        arr = @index[name] ||= []
        arr << node
      when Send
        match = attr_method(node.method)
        return unless match
        node.args.each do |arg|
          if match[1] == "reader"
            full_name, method_name = rewrite_attr_reader(arg, node.parent_scope)
            add_to_index(full_name, method_name, node.loc)
          elsif match [1] == "writer"
            full_name, method_name = rewrite_attr_writer(arg, node.parent_scope)
            add_to_index(full_name, method_name, node.loc)
          elsif match[1] == "accessor"
            reader_full_name, reader_method_name = rewrite_attr_reader(arg, node.parent_scope)
            writer_full_name, writer_method_name = rewrite_attr_writer(arg, node.parent_scope)

            add_to_index(reader_full_name, reader_method_name, node.loc)
            add_to_index(writer_full_name, writer_method_name, node.loc)
          end
        end
      end
    end

    sig { params(method: Symbol).returns(T.nilable(MatchData)) }
    def attr_method(method)
      method.match(ATTR_REGEX)
    end

    sig { params(arg: String, scope: T.nilable(Scope)).returns([String, String]) }
    def rewrite_attr_reader(arg, scope)
      method_name = T.must(arg[1..-1])
      sep = "#" # TODO: Handle singletons with better SClass support
      str = "#{sep}#{method_name}"
      return [str, method_name] unless scope
      ["#{scope.qualified_name}#{str}", method_name]
    end

    sig { params(arg: String, scope: T.nilable(Scope)).returns([String, String]) }
    def rewrite_attr_writer(arg, scope)
      method_name = T.must(arg[1..-1])
      sep = "#" # TODO: Handle singletons with better SClass support
      str = "#{sep}#{method_name}="
      return str, method_name unless scope
      ["#{scope.qualified_name}#{str}", method_name]
    end

    sig { params(key: String, method_name: String, method_loc: T.nilable(Loc)).void }
    def add_to_index(key, method_name, method_loc)
      arr = @index[key] ||= []
      method = Method.new(method_name, loc: method_loc)
      arr << method
    end
  end
end
