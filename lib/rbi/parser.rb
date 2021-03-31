# typed: strict
# frozen_string_literal: true

module RBI
  class Parser
    extend T::Sig

    class Error < StandardError; end

    # opt-in to most recent AST format:
    ::Parser::Builders::Default.emit_lambda   = true
    ::Parser::Builders::Default.emit_procarg0 = true
    ::Parser::Builders::Default.emit_encoding = true
    ::Parser::Builders::Default.emit_index    = true

    sig { params(paths: String).returns(T::Array[String]) }
    def self.list_files(*paths)
      files = T.let([], T::Array[String])
      paths.each do |path|
        unless ::File.exist?(path)
          $stderr.puts("can't find `#{path}`.")
          next
        end
        if ::File.directory?(path)
          files = files.concat(Dir.glob(Pathname.new("#{path}/**/*.rbi").cleanpath))
        else
          files << path
        end
      end
      files.uniq.sort
    end

    sig { params(string: String).returns(RBI::Tree) }
    def self.parse_string(string)
      Parser.new.parse_string(string)
    end

    sig { params(path: String).returns(RBI::Tree) }
    def self.parse_file(path)
      Parser.new.parse_file(path)
    end

    sig { params(string: String).returns(RBI::Tree) }
    def parse_string(string)
      node = ::Parser::CurrentRuby.parse(string)
      builder = TreeBuilder.new
      builder.visit(node)
      builder.tree
    rescue ::Parser::SyntaxError => e
      raise Error, e.message
    end

    sig { params(path: String).returns(RBI::Tree) }
    def parse_file(path)
      node = ::Parser::CurrentRuby.parse_file(path)
      node = ::Parser::CurrentRuby.parse_file(path)
      builder = TreeBuilder.new(path)
      builder.visit(node)
      builder.tree
    rescue ::Parser::SyntaxError => e
      raise Error, e.message
    end
  end

  class ASTVisitor
    extend T::Helpers
    extend T::Sig

    abstract!

    sig { params(nodes: T::Array[AST::Node]).void }
    def visit_all(nodes)
      nodes.each { |node| visit(node) }
    end

    sig { abstract.params(node: T.nilable(AST::Node)).void }
    def visit(node); end
  end

  class TreeBuilder < ASTVisitor
    extend T::Sig

    sig { returns(Tree) }
    attr_reader :tree

    sig { params(file: String).void }
    def initialize(file = "-")
      super()
      @file = file
      @tree = T.let(Tree.new, Tree)
      @scopes_stack = T.let([@tree], T::Array[Tree])
    end

    sig { returns(Tree) }
    def current_scope
      T.must(@scopes_stack.last) # Should never be nil since we create a Tree as the root
    end

    sig { override.params(node: T.nilable(Object)).void }
    def visit(node)
      return unless node.is_a?(AST::Node)
      case node.type
      when :module
        visit_module(node)
      else
        visit_all(node.children)
      end
    end

    sig { params(node: AST::Node).void }
    def visit_module(node)
      scope = case node.type
      when :module
        name = T.must(ConstBuilder.visit(node.children[0]))
        Module.new(name)
      else
        raise "Unsupported node #{node.type}"
      end
      current_scope << scope

      @scopes_stack << scope
      visit_all(node.children)
      @scopes_stack.pop
    end
  end

  class ConstBuilder < ASTVisitor
    extend T::Sig

    sig { params(node: T.nilable(AST::Node)).returns(T.nilable(String)) }
    def self.visit(node)
      v = ConstBuilder.new
      v.visit(node)
      return nil if v.names.empty?
      v.names.join("::")
    end

    sig { returns(T::Array[String]) }
    attr_accessor :names

    sig { void }
    def initialize
      super
      @names = T.let([], T::Array[String])
    end

    sig { override.params(node: T.nilable(AST::Node)).void }
    def visit(node)
      return unless node
      case node.type
      when :const
        visit(node.children[0])
        @names << node.children[1].to_s
      end
    end
  end
end