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

    sig { params(node: Node).void }
    def index(node)
      case node
      when Scope, Method, Const
        name = node.qualified_name
        add_to_index(name, node)
      when Send
        send_method = node.method
        case send_method
        when :attr_reader
          node.args.each { |arg| index_attr_reader(arg, node) }
        when :attr_writer
          node.args.each { |arg| index_attr_writer(arg, node) }
        when :attr_accessor
          node.args.each { |arg| index_attr_accessor(arg, node) }
        end
      end
    end

    sig { params(arg: String, node: Node).void }
    def index_attr_reader(arg, node)
      scope = node.parent_scope
      method_name = T.must(arg[1..-1])
      sep = "#" # TODO: Handle singletons with better SClass support
      full_name = "#{sep}#{method_name}"
      if scope
        full_name = "#{scope.qualified_name}#{full_name}"
      end

      add_to_index(full_name, node)
    end

    sig { params(arg: String, node: Node).void }
    def index_attr_writer(arg, node)
      scope = node.parent_scope
      method_name = T.must(arg[1..-1])
      sep = "#" # TODO: Handle singletons with better SClass support
      full_name = "#{sep}#{method_name}="
      if scope
        full_name = "#{scope.qualified_name}#{full_name}"
      end

      add_to_index(full_name, node)
    end

    sig { params(arg: String, node: Node).void }
    def index_attr_accessor(arg, node)
      index_attr_reader(arg, node)
      index_attr_writer(arg, node)
    end

    sig { params(key: String, node: Node).void }
    def add_to_index(key, node)
      arr = @index[key] ||= []
      arr << node
    end
  end
end
