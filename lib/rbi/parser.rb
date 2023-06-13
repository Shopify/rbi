# typed: strict
# frozen_string_literal: true

require "parser"
require "syntax_tree"

module RBI
  class ParseError < StandardError
    extend T::Sig

    sig { returns(Loc) }
    attr_reader :location

    sig { params(message: String, location: Loc).void }
    def initialize(message, location)
      super(message)
      @location = location
    end
  end

  class UnexpectedParserError < StandardError
    extend T::Sig

    sig { returns(Loc) }
    attr_reader :last_location

    sig { params(parent_exception: Exception, last_location: Loc).void }
    def initialize(parent_exception, last_location)
      super(parent_exception)
      set_backtrace(parent_exception.backtrace)
      @last_location = last_location
    end

    sig { params(io: T.any(IO, StringIO)).void }
    def print_debug(io: $stderr)
      io.puts ""
      io.puts "##################################"
      io.puts "### RBI::Parser internal error ###"
      io.puts "##################################"
      io.puts ""
      io.puts "There was an internal parser error while processing this source."
      io.puts ""
      io.puts "Error: #{message} while parsing #{last_location}:"
      io.puts ""
      io.puts last_location.source || "<no source>"
      io.puts ""
      io.puts "Please open an issue at https://github.com/Shopify/rbi/issues/new."
      io.puts ""
      io.puts "##################################"
      io.puts ""
    end
  end

  class Parser < SyntaxTree::Visitor
    extend T::Sig

    class << self
      extend T::Sig

      sig { params(string: String).returns(Tree) }
      def parse_string(string)
        Parser.new.parse_string(string)
      end

      sig { params(path: String).returns(Tree) }
      def parse_file(path)
        Parser.new.parse_file(path)
      end

      sig { params(paths: T::Array[String]).returns(T::Array[Tree]) }
      def parse_files(paths)
        parser = Parser.new
        paths.map { |path| parser.parse_file(path) }
      end

      sig { params(strings: T::Array[String]).returns(T::Array[Tree]) }
      def parse_strings(strings)
        parser = Parser.new
        strings.map { |string| parser.parse_string(string) }
      end
    end

    sig { params(string: String).returns(Tree) }
    def parse_string(string)
      parse(string, file: "-")
    end

    sig { params(path: String).returns(Tree) }
    def parse_file(path)
      parse(::File.read(path), file: path)
    end

    private

    sig { params(source: String, file: String).returns(Tree) }
    def parse(source, file:)
      ast = SyntaxTree.parse(source)
      visitor = TreeBuilder.new(source, file: file)
      visitor.visit(ast)
      visitor.tree
    rescue SyntaxTree::Parser::ParseError => e
      raise ParseError.new(
        e.message,
        Loc.new(file: file, begin_line: e.lineno, begin_column: e.column, end_line: e.lineno, end_column: e.column),
      )
    rescue ParseError => e
      raise e
    rescue => e
      last_node = visitor&.last_node
      last_location = if last_node
        Loc.from_syntax_tree(file, last_node.location)
      else
        Loc.new(file: file)
      end

      exception = UnexpectedParserError.new(e, last_location)
      exception.print_debug
      raise exception
    end

    class Visitor < SyntaxTree::Visitor
      extend T::Sig

      sig { params(source: String, file: String).void }
      def initialize(source, file:)
        super()

        @source = source
        @file = file
      end

      sig { params(node: SendNode).void }
      def visit_send(node)
      end

      sig { override.params(node: SyntaxTree::CallNode).void }
      def visit_call(node)
        visit_send(make_send(node))
      end

      sig { override.params(node: SyntaxTree::Command).void }
      def visit_command(node)
        visit_send(make_send(node))
      end

      sig { override.params(node: SyntaxTree::CommandCall).void }
      def visit_command_call(node)
        visit_send(make_send(node))
      end

      sig { override.params(node: SyntaxTree::VCall).void }
      def visit_vcall(node)
        visit_send(make_send(node))
      end

      sig { override.params(node: SyntaxTree::MethodAddBlock).void }
      def visit_method_add_block(node)
        visit_send(make_send(node))
      end

      private

      sig do
        params(
          node: T.any(
            SyntaxTree::ARef,
            SyntaxTree::CallNode,
            SyntaxTree::Command,
            SyntaxTree::CommandCall,
            SyntaxTree::MethodAddBlock,
            SyntaxTree::VCall,
            SyntaxTree::Super,
            SyntaxTree::ZSuper,
          ),
        ).returns(SendNode)
      end
      def make_send(node)
        recv = nil
        message = nil
        args_node = nil

        case node
        when SyntaxTree::ARef
          recv = node.collection
          message = "[]"
          args_node = node.index
        when SyntaxTree::CallNode
          recv = node.receiver
          message = node_string!(node.message)
          args_node = node.arguments
        when SyntaxTree::Command
          message = node_string!(node.message)
          args_node = node.arguments
          block_node = node.block
        when SyntaxTree::CommandCall
          message = node_string!(node.message)
          args_node = node.arguments
          block_node = node.block
        when SyntaxTree::VCall
          message = node_string!(node.value)
        when SyntaxTree::MethodAddBlock
          send = make_send(node.call)
          recv = send.receiver
          message = send.message
          args_node = send.args
          block_node = node.block
        when SyntaxTree::Super
          message = "super"
          args_node = node.arguments
        when SyntaxTree::ZSuper
          message = "super"
        end

        args_node = args_node.arguments if args_node.is_a?(SyntaxTree::ArgParen)

        args = case args_node
        when Array
          args_node
        when SyntaxTree::Args
          args_node.parts
        when SyntaxTree::ArgsForward
          [args_node]
        else
          []
        end

        SendNode.new(node: node, receiver: recv, message: message, args: args, block: block_node)
      end

      sig { params(node: SyntaxTree::Node).returns(Loc) }
      def node_loc(node)
        Loc.from_syntax_tree(@file, node.location)
      end

      sig { params(node: T.any(NilClass, Symbol, SyntaxTree::Node)).returns(T.nilable(String)) }
      def node_string(node)
        return unless node
        return node.to_s if node.is_a?(Symbol)

        @source[node.location.start_char...node.location.end_char]
      end

      sig { params(node: T.any(Symbol, SyntaxTree::Node)).returns(String) }
      def node_string!(node)
        return node.to_s if node.is_a?(Symbol)

        T.must(@source[node.location.start_char...node.location.end_char])
      end
    end

    class TreeBuilder < Visitor
      extend T::Sig

      sig { returns(Tree) }
      attr_reader :tree

      sig { returns(T.nilable(SyntaxTree::Node)) }
      attr_reader :last_node

      sig { params(source: String, file: String).void }
      def initialize(source, file:)
        super

        @tree = T.let(Tree.new, Tree)

        @scopes_stack = T.let([@tree], T::Array[Tree])
        @last_node = T.let(nil, T.nilable(SyntaxTree::Node))
        @last_sigs = T.let([], T::Array[RBI::Sig])
        @last_sigs_comments = T.let([], T::Array[Comment])
        @last_comments = T.let([], T::Array[Comment])
      end

      sig { override.params(node: T.nilable(SyntaxTree::Node)).void }
      def visit(node)
        return unless node

        @last_node = node
        super
      end

      sig { override.params(node: SyntaxTree::Assign).void }
      def visit_assign(node)
        target = node.target

        return unless target.is_a?(SyntaxTree::ConstPathField) || target.is_a?(SyntaxTree::TopConstField) ||
          (target.is_a?(SyntaxTree::VarField) && target.value.is_a?(SyntaxTree::Const))

        struct = parse_struct(node)

        current_scope << if struct
          struct
        elsif type_variable_definition?(node.value)
          TypeMember.new(
            node_string!(node.target),
            node_string!(node.value),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        else
          Const.new(
            node_string!(target),
            node_string!(node.value),
            loc: node_loc(node),
            comments: node_comments(node),
          )
        end
      end

      sig { override.params(node: SyntaxTree::ClassDeclaration).void }
      def visit_class(node)
        scope = Class.new(
          node_string!(node.constant),
          superclass_name: node_string(node.superclass),
          loc: node_loc(node),
          comments: node_comments(node),
        )

        current_scope << scope
        @scopes_stack << scope
        visit(node.bodystmt)
        collect_dangling_comments
        @scopes_stack.pop
      end

      sig { override.params(node: SyntaxTree::Comment).void }
      def visit_comment(node)
        @last_comments << parse_comment(node)
      end

      sig { override.params(node: SyntaxTree::DefNode).void }
      def visit_def(node)
        current_scope << Method.new(
          node_string!(node.name),
          params: parse_params(node),
          sigs: current_sigs,
          loc: node_loc(node),
          comments: current_sigs_comments + node_comments(node),
          is_singleton: !!node.target,
        )
      end

      sig { override.params(node: SyntaxTree::ModuleDeclaration).void }
      def visit_module(node)
        scope = Module.new(node_string!(node.constant), loc: node_loc(node), comments: node_comments(node))

        current_scope << scope
        @scopes_stack << scope
        visit(node.bodystmt)
        collect_dangling_comments
        @scopes_stack.pop
      end

      sig { override.params(node: SyntaxTree::Program).void }
      def visit_program(node)
        super

        collect_dangling_comments
        separate_header_comments
        set_root_tree_loc
      end

      sig { override.params(node: SyntaxTree::SClass).void }
      def visit_sclass(node)
        scope = SingletonClass.new(loc: node_loc(node), comments: node_comments(node))

        current_scope << scope
        @scopes_stack << scope
        visit(node.bodystmt)
        collect_dangling_comments
        @scopes_stack.pop
      end

      sig { params(node: SendNode).void }
      def visit_send(node)
        message = node.message
        case message
        when "abstract!", "sealed!", "interface!"
          current_scope << Helper.new(
            message.delete_suffix("!"),
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        when "attr_reader"
          current_scope << AttrReader.new(
            *T.unsafe(node.args.map { |arg| T.must(node_string!(arg)[1..-1]).to_sym }),
            sigs: current_sigs,
            loc: node_loc(node.node),
            comments: current_sigs_comments + node_comments(node.node),
          )
        when "attr_writer"
          current_scope << AttrWriter.new(
            *T.unsafe(node.args.map { |arg| T.must(node_string!(arg)[1..-1]).to_sym }),
            sigs: current_sigs,
            loc: node_loc(node.node),
            comments: current_sigs_comments + node_comments(node.node),
          )
        when "attr_accessor"
          current_scope << AttrAccessor.new(
            *T.unsafe(node.args.map { |arg| T.must(node_string!(arg)[1..-1]).to_sym }),
            sigs: current_sigs,
            loc: node_loc(node.node),
            comments: current_sigs_comments + node_comments(node.node),
          )
        when "enums"
          block = node.block&.bodystmt
          stmts = case block
          when SyntaxTree::BodyStmt
            block.statements.body
          when SyntaxTree::Statements
            block.body
          else
            []
          end
          current_scope << TEnumBlock.new(
            stmts.map { |stmt| node_string!(T.cast(stmt, SyntaxTree::Assign).target) },
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        when "extend"
          current_scope << Extend.new(
            *T.unsafe(node.args.map { |arg| node_string!(arg) }),
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        when "include"
          current_scope << Include.new(
            *T.unsafe(node.args.map { |arg| node_string!(arg) }),
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        when "mixes_in_class_methods"
          current_scope << MixesInClassMethods.new(
            *T.unsafe(node.args.map { |arg| node_string!(arg) }),
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        when "private", "protected", "public"
          case node.node
          when SyntaxTree::VCall
            current_scope << parse_visibility(node.message, node.node)
          when SyntaxTree::Command
            visit_all(node.args)
            last_node = @scopes_stack.last&.nodes&.last
            case last_node
            when Method, Attr
              last_node.visibility = parse_visibility(node.message, node.node)
            else
              raise ParseError.new(
                "Unexpected token `#{node.message}` before `#{last_node&.string&.strip}`",
                node_loc(node.node),
              )
            end
          end
        when "prop", "const"
          parse_tstruct_field(node)
        when "requires_ancestor"
          block = node.block&.bodystmt

          block = case block
          when SyntaxTree::BodyStmt
            block.statements
          when SyntaxTree::Statements
            block
          end

          current_scope << RequiresAncestor.new(
            node_string!(T.must(block&.body&.first)),
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        when "sig"
          @last_sigs << parse_sig(node)
        when nil
        else
          current_scope << Send.new(
            message,
            parse_send_args(node.args),
            loc: node_loc(node.node),
            comments: node_comments(node.node),
          )
        end
      end

      private

      sig { void }
      def collect_dangling_comments
        last_line = T.let(nil, T.nilable(Integer))

        @last_comments.each do |comment|
          comment_line = T.must(comment.loc&.begin_line)

          if last_line && comment_line > last_line + 1
            # Preserve empty lines in file headers
            current_scope << BlankLine.new(loc: comment.loc)
          end

          current_scope << comment

          last_line = T.must(comment.loc&.end_line)
        end
        @last_comments.clear
      end

      sig { returns(Tree) }
      def current_scope
        T.must(@scopes_stack.last) # Should never be nil since we create a Tree as the root
      end

      sig { returns(T::Array[Sig]) }
      def current_sigs
        sigs = @last_sigs.dup
        @last_sigs.clear
        sigs
      end

      sig { returns(T::Array[Comment]) }
      def current_sigs_comments
        comments = @last_sigs_comments.dup
        @last_sigs_comments.clear
        comments
      end

      sig { params(node: SyntaxTree::Node).returns(T::Array[Comment]) }
      def node_comments(node)
        node_comments = []
        unless @last_comments.empty?
          current_line = node.location.start_line
          @last_comments.reverse.each do |comment|
            comment_loc = T.must(comment.loc)
            if comment_loc.end_line == current_line - 1
              node_comments << @last_comments.pop
              current_line = comment_loc.end_line
            end
          end
        end

        collect_dangling_comments

        node_comments.reverse!
        T.unsafe(node).comments.each do |comment_node|
          node_comments << parse_comment(comment_node)
        end
        node_comments
      end

      sig { params(node: SyntaxTree::Comment).returns(Comment) }
      def parse_comment(node)
        Comment.new(node.value.gsub(/^# ?/, ""), loc: node_loc(node))
      end

      sig { params(nodes: T::Array[SyntaxTree::Node]).returns(T::Array[Arg]) }
      def parse_send_args(nodes)
        args = T.let([], T::Array[Arg])
        nodes.each do |child|
          case child
          when SyntaxTree::BareAssocHash
            child.assocs.each do |assoc|
              case assoc
              when SyntaxTree::Assoc
                keyword = node_string!(assoc.key).delete_suffix(":")
                value = T.must(node_string(assoc.value))
                args << KwArg.new(keyword, value)
              end
            end
          else
            args << Arg.new(T.must(node_string(child)))
          end
        end
        args
      end

      sig { params(node: SyntaxTree::DefNode).returns(T::Array[Param]) }
      def parse_params(node)
        params = []

        params_node = node.params

        case params_node
        when SyntaxTree::Paren
          params_node = T.cast(params_node.contents, SyntaxTree::Params)
        when nil
          return params
        end

        params_node.requireds.each do |ident|
          params << ReqParam.new(node_string!(ident), loc: node_loc(ident), comments: node_comments(ident))
        end

        params_node.optionals.each do |(ident, value)|
          params << OptParam.new(
            node_string!(ident),
            node_string!(value),
            loc: node_loc(ident),
            comments: node_comments(ident),
          )
        end

        rest = params_node.rest
        if rest
          params << RestParam.new(
            node_string!(rest).delete_prefix("*"),
            loc: node_loc(rest),
            comments: node_comments(rest),
          )
        end

        params_node.keywords.each do |(label, value)|
          params << if value
            KwOptParam.new(
              node_string!(label).delete_suffix(":"),
              node_string!(value),
              loc: node_loc(label),
              comments: node_comments(label),
            )
          else
            KwParam.new(
              node_string!(label).delete_suffix(":"),
              loc: node_loc(label),
              comments: node_comments(label),
            )
          end
        end

        rest_kw = params_node.keyword_rest
        if rest_kw.is_a?(SyntaxTree::KwRestParam)
          params << KwRestParam.new(
            node_string!(rest_kw).delete_prefix("**"),
            loc: node_loc(rest_kw),
            comments: node_comments(rest_kw),
          )
        elsif !rest_kw.nil?
          raise ParseError.new("Unexpected keyword rest type: #{rest_kw.class}", node_loc(params_node))
        end

        block = params_node.block
        if block
          params << BlockParam.new(
            node_string!(block).delete_prefix("&"),
            loc: node_loc(block),
            comments: node_comments(block),
          )
        end

        params
      end

      sig { params(node: SendNode).returns(Sig) }
      def parse_sig(node)
        @last_sigs_comments = node_comments(node.node)

        builder = SigBuilder.new(@source, file: @file)
        builder.current.loc = node_loc(node.node)
        builder.visit_send(node)
        builder.current
      end

      sig { params(node: SyntaxTree::Assign).returns(T.nilable(Struct)) }
      def parse_struct(node)
        value = node.value
        send = nil

        case value
        when SyntaxTree::CallNode, SyntaxTree::MethodAddBlock
          send = make_send(value)

          return unless send.message == "new"

          recv = send.receiver
          return unless recv
          return unless node_string(recv) =~ /(::)?Struct/
        end

        return unless send

        members = []
        keyword_init = T.let(false, T::Boolean)

        send.args.each do |arg|
          case arg
          when SyntaxTree::SymbolLiteral
            members << arg.value.value
          when SyntaxTree::BareAssocHash
            arg.assocs.each do |assoc|
              case assoc
              when SyntaxTree::Assoc
                key = node_string!(assoc.key)
                val = node_string(assoc.value)

                keyword_init = val == "true" if key == "keyword_init:"
              end
            end
          else
            raise ParseError.new("Unexpected node type `#{arg.class}`", node_loc(arg))
          end
        end

        name = node_string!(node.target)
        loc = node_loc(node)
        comments = node_comments(node)
        struct = Struct.new(name, members: members, keyword_init: keyword_init, loc: loc, comments: comments)
        @scopes_stack << struct
        visit(send.block)
        @scopes_stack.pop
        struct
      end

      sig { params(send: SendNode).void }
      def parse_tstruct_field(send)
        name_arg, type_arg, *rest = send.args
        return unless name_arg
        return unless type_arg

        name = node_string!(name_arg).delete_prefix(":")
        type = node_string!(type_arg)
        loc = node_loc(send.node)
        comments = node_comments(send.node)
        default_value = T.let(nil, T.nilable(String))

        rest&.each do |arg|
          next unless arg.is_a?(SyntaxTree::BareAssocHash)

          arg.assocs.each do |assoc|
            next unless assoc.is_a?(SyntaxTree::Assoc)

            if node_string(assoc.key) == "default:"
              default_value = node_string(assoc.value)
            end
          end
        end

        current_scope << case send.message
        when "const"
          TStructConst.new(name, type, default: default_value, loc: loc, comments: comments)
        when "prop"
          TStructProp.new(name, type, default: default_value, loc: loc, comments: comments)
        else
          raise ParseError.new("Unexpected message `#{send.message}`", loc)
        end
      end

      sig { params(name: String, node: SyntaxTree::Node).returns(Visibility) }
      def parse_visibility(name, node)
        case name
        when "public"
          Public.new(loc: node_loc(node))
        when "protected"
          Protected.new(loc: node_loc(node))
        when "private"
          Private.new(loc: node_loc(node))
        else
          raise ParseError.new("Unexpected visibility `#{name}`", node_loc(node))
        end
      end

      sig { void }
      def separate_header_comments
        current_scope.nodes.dup.each do |child_node|
          break unless child_node.is_a?(Comment) || child_node.is_a?(BlankLine)

          current_scope.comments << child_node
          child_node.detach
        end
      end

      sig { void }
      def set_root_tree_loc
        first_loc = tree.nodes.first&.loc
        last_loc = tree.nodes.last&.loc

        @tree.loc = Loc.new(
          file: @file,
          begin_line: first_loc&.begin_line || 0,
          begin_column: first_loc&.begin_column || 0,
          end_line: last_loc&.end_line || 0,
          end_column: last_loc&.end_column || 0,
        )
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def type_variable_definition?(node)
        return false unless node.is_a?(SyntaxTree::MethodAddBlock)

        call = node.call
        return false unless call.is_a?(SyntaxTree::CallNode)

        message = node_string(call.message)
        return false unless message == "type_member" || message == "type_template"

        true
      end
    end

    class SigBuilder < Visitor
      extend T::Sig

      sig { returns(Sig) }
      attr_accessor :current

      sig { params(content: String, file: String).void }
      def initialize(content, file:)
        super

        @current = T.let(Sig.new, Sig)
      end

      sig { override.params(node: SendNode).void }
      def visit_send(node)
        case node.message
        when "sig"
          node.args.each do |arg|
            @current.is_final = node_string(arg) == ":final"
          end
        when "abstract"
          @current.is_abstract = true
        when "checked"
          arg = node_string(node.args.first)
          @current.checked = arg&.delete_prefix(":")&.to_sym
        when "override"
          @current.is_override = true
        when "overridable"
          @current.is_overridable = true
        when "params"
          visit_all(node.args)
        when "returns"
          first = node.args.first
          @current.return_type = node_string!(first) if first
        when "type_parameters"
          node.args.each do |arg|
            @current.type_params << node_string!(arg).delete_prefix(":")
          end
        when "void"
          @current.return_type = nil
        end

        visit(node.receiver)
        visit(node.block)
      end

      sig { override.params(node: SyntaxTree::BareAssocHash).void }
      def visit_bare_assoc_hash(node)
        node.assocs.each do |assoc|
          case assoc
          when SyntaxTree::Assoc
            @current.params << SigParam.new(
              node_string!(assoc.key).delete_suffix(":"),
              node_string!(T.must(assoc.value)),
            )
          end
        end
      end
    end
  end

  class SendNode < T::Struct
    const :node, SyntaxTree::Node
    const :receiver, T.nilable(SyntaxTree::Node)
    const :message, String
    const :args, T::Array[SyntaxTree::Node], default: []
    const :block, T.nilable(SyntaxTree::BlockNode)
  end

  class Loc
    class << self
      extend T::Sig

      sig { params(file: String, location: SyntaxTree::Location).returns(Loc) }
      def from_syntax_tree(file, location)
        new(
          file: file,
          begin_line: location.start_line,
          begin_column: location.start_column,
          end_line: location.end_line,
          end_column: location.end_column,
        )
      end
    end
  end
end
