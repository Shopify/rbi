# typed: strict
# frozen_string_literal: true

# We need to collect the comments with `current_sigs_comments` _before_ visiting the parameters to make sure
# the method comments are properly associated with the sigs and not the parameters.

# Associate the comment either with the header or the file or as a dangling comment at the end

# Preserve blank lines in comments

# Should never be nil since we create a Tree as the root

require "prism"

module RBI
  class ParseError < Error
    sig { returns(Loc) }
    attr_reader :location

    sig { params(message: String, location: Loc).void }
    def initialize(message, location); end
  end

  class UnexpectedParserError < Error
    sig { returns(Loc) }
    attr_reader :last_location

    sig { params(parent_exception: Exception, last_location: Loc).void }
    def initialize(parent_exception, last_location); end

    sig { params(io: T.any(IO, StringIO)).void }
    def print_debug(io: $stderr); end
  end

  class Parser
    class << self
      sig { params(string: String).returns(Tree) }
      def parse_string(string); end

      sig { params(path: String).returns(Tree) }
      def parse_file(path); end

      sig { params(paths: T::Array[String]).returns(T::Array[Tree]) }
      def parse_files(paths); end

      sig { params(strings: T::Array[String]).returns(T::Array[Tree]) }
      def parse_strings(strings); end
    end

    sig { params(string: String).returns(Tree) }
    def parse_string(string); end

    sig { params(path: String).returns(Tree) }
    def parse_file(path); end

    private

    sig { params(source: String, file: String).returns(Tree) }
    def parse(source, file:); end

    class Visitor < Prism::Visitor
      sig { params(source: String, file: String).void }
      def initialize(source, file:); end

      private

      sig { params(node: Prism::Node).returns(Loc) }
      def node_loc(node); end

      sig { params(node: T.nilable(Prism::Node)).returns(T.nilable(String)) }
      def node_string(node); end

      sig { params(node: Prism::Node).returns(String) }
      def node_string!(node); end
    end

    class TreeBuilder < Visitor
      sig { returns(Tree) }
      attr_reader :tree

      sig { returns(T.nilable(Prism::Node)) }
      attr_reader :last_node

      sig { params(source: String, comments: T::Array[Prism::Comment], file: String).void }
      def initialize(source, comments:, file:); end

      # @override
      sig { params(node: Prism::ClassNode).void }
      def visit_class_node(node); end

      # @override
      sig { params(node: Prism::ConstantWriteNode).void }
      def visit_constant_write_node(node); end

      # @override
      sig { params(node: Prism::ConstantPathWriteNode).void }
      def visit_constant_path_write_node(node); end

      sig { params(node: T.any(Prism::ConstantWriteNode, Prism::ConstantPathWriteNode)).void }
      def visit_constant_assign(node); end

      # @override
      sig { params(node: Prism::DefNode).void }
      def visit_def_node(node); end

      # @override
      sig { params(node: Prism::ModuleNode).void }
      def visit_module_node(node); end

      # @override
      sig { params(node: Prism::ProgramNode).void }
      def visit_program_node(node); end

      # @override
      sig { params(node: Prism::SingletonClassNode).void }
      def visit_singleton_class_node(node); end

      sig { params(node: Prism::CallNode).void }
      def visit_call_node(node); end

      private

      # Collect all the remaining comments within a node
      sig { params(node: Prism::Node).void }
      def collect_dangling_comments(node); end

      # Collect all the remaining comments after visiting the tree
      sig { void }
      def collect_orphan_comments; end

      sig { returns(Tree) }
      def current_scope; end

      sig { returns(T::Array[Sig]) }
      def current_sigs; end

      sig { params(sigs: T::Array[Sig]).returns(T::Array[Comment]) }
      def detach_comments_from_sigs(sigs); end

      sig { params(node: Prism::Node).returns(T::Array[Comment]) }
      def node_comments(node); end

      sig { params(node: Prism::Comment).returns(Comment) }
      def parse_comment(node); end

      sig { params(node: T.nilable(Prism::Node)).returns(T::Array[Arg]) }
      def parse_send_args(node); end

      sig { params(node: T.nilable(Prism::Node)).returns(T::Array[Param]) }
      def parse_params(node); end

      sig { params(node: Prism::CallNode).returns(Sig) }
      def parse_sig(node); end

      sig { params(node: T.any(Prism::ConstantWriteNode, Prism::ConstantPathWriteNode)).returns(T.nilable(Struct)) }
      def parse_struct(node); end

      sig { params(send: Prism::CallNode).void }
      def parse_tstruct_field(send); end

      sig { params(name: String, node: Prism::Node).returns(Visibility) }
      def parse_visibility(name, node); end

      sig { void }
      def separate_header_comments; end

      sig { void }
      def set_root_tree_loc; end

      sig { params(node: T.nilable(Prism::Node)).returns(T::Boolean) }
      def type_variable_definition?(node); end
    end

    class SigBuilder < Visitor
      sig { returns(Sig) }
      attr_reader :current

      sig { params(content: String, file: String).void }
      def initialize(content, file:); end

      # @override
      sig { params(node: Prism::CallNode).void }
      def visit_call_node(node); end

      # @override
      sig { params(node: Prism::AssocNode).void }
      def visit_assoc_node(node); end
    end
  end
end
