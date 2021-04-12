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
      node, comments = ::Parser::CurrentRuby.parse_with_comments(string)
      assoc = ::Parser::Source::Comment.associate_locations(node, comments)
      builder = TreeBuilder.new(comments: assoc)
      builder.visit(node)
      builder.tree
    rescue ::Parser::SyntaxError => e
      raise Error, e.message
    end

    sig { params(path: String).returns(RBI::Tree) }
    def parse_file(path)
      node, comments = ::Parser::CurrentRuby.parse_file_with_comments(path)
      assoc = ::Parser::Source::Comment.associate_locations(node, comments)
      builder = TreeBuilder.new(file: path, comments: assoc)
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

    sig do
      params(
        file: String,
        comments: T.nilable(T::Hash[::Parser::Source::Map, T::Array[::Parser::Source::Comment]])
      ).void
    end
    def initialize(file: "-", comments: nil)
      super()
      @file = file
      @comments = comments
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
      when :module, :class, :sclass
        visit_scope(node)
      when :casgn
        visit_const_assign(node)
      when :def, :defs
        visit_def(node)
      when :send
        visit_send(node)
      else
        visit_all(node.children)
      end
    end

    sig { params(node: AST::Node).void }
    def visit_scope(node)
      loc = node_loc(node)
      comments = node_comments(node)
      scope = case node.type
      when :module
        name = T.must(ConstBuilder.visit(node.children[0]))
        Module.new(name, loc: loc, comments: comments)
      when :class
        name = T.must(ConstBuilder.visit(node.children[0]))
        superclass_name = ConstBuilder.visit(node.children[1])
        Class.new(name, superclass_name: superclass_name, loc: loc, comments: comments)
      when :sclass
        SClass.new(loc: loc, comments: comments)
      else
        raise "Unsupported node #{node.type}"
      end
      current_scope << scope

      @scopes_stack << scope
      visit_all(node.children)
      @scopes_stack.pop
    end

    sig { params(node: AST::Node).void }
    def visit_const_assign(node)
      name = T.must(ConstBuilder.visit(node))
      current_scope << Const.new(name, loc: node_loc(node), comments: node_comments(node))
    end

    sig { params(node: AST::Node).void }
    def visit_def(node)
      loc = node_loc(node)
      case node.type
      when :def
        current_scope << Method.new(
          node.children[0].to_s,
          params: node.children[1].children.map { |child| visit_param(child) },
          loc: loc,
          comments: node_comments(node)
        )
      when :defs
        current_scope << Method.new(
          node.children[1].to_s,
          params: node.children[2].children.map { |child| visit_param(child) },
          is_singleton: true,
          loc: loc,
          comments: node_comments(node)
        )
      else
        raise "Unsupported node #{node.type}"
      end
    end

    sig { params(node: AST::Node).returns(Param) }
    def visit_param(node)
      loc = node_loc(node)
      name = node.children[0].to_s
      comments = node_comments(node)
      case node.type
      when :arg
        Param.new(name, loc: loc, comments: comments)
      when :optarg
        Param.new(name, loc: loc, comments: comments, is_optional: true)
      when :restarg
        Param.new(name, loc: loc, comments: comments, is_rest: true)
      when :kwarg
        Param.new(name, loc: loc, comments: comments, is_keyword: true)
      when :kwoptarg
        Param.new(name, loc: loc, comments: comments, is_keyword: true, is_optional: true)
      when :kwrestarg
        Param.new(name, loc: loc, comments: comments, is_keyword: true, is_rest: true)
      when :blockarg
        Param.new(name, loc: loc, comments: comments, is_block: true)
      else
        raise "Unsupported node #{node.type}"
      end
    end

    sig { params(node: AST::Node).void }
    def visit_send(node)
      recv = node.children[0]
      return if recv && recv != :self

      name = node.children[1]
      args = node.children[2..-1].map do |child|
        ConstBuilder.visit(child)
      end
      current_scope << Send.new(name, args: args, loc: node_loc(node), comments: node_comments(node))
    end

    private

    sig { params(node: AST::Node).returns(Loc) }
    def node_loc(node)
      ast_to_rbi_loc(node.location)
    end

    sig { params(ast_loc: ::Parser::Source::Map).returns(Loc) }
    def ast_to_rbi_loc(ast_loc)
      Loc.new(
        file: @file,
        begin_line: ast_loc.line,
        begin_column: ast_loc.column,
        end_line: ast_loc.last_line,
        end_column: ast_loc.last_column
      )
    end

    sig { params(node: AST::Node).returns(T::Array[Comment]) }
    def node_comments(node)
      return [] unless @comments
      comments = @comments[node.location]
      return [] unless comments
      comments.map { |comment| Comment.new(comment.text, loc: ast_to_rbi_loc(comment.location)) }
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
      when :const, :casgn
        visit(node.children[0])
        @names << node.children[1].to_s
      when :cbase
        @names << ""
      when :sym
        @names << ":#{node.children[0]}"
      end
    end
  end
end
