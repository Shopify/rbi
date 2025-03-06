# typed: strict
# frozen_string_literal: true

module RBI
  class Formatter
    sig { returns(T.nilable(Integer)) }
    attr_accessor :max_line_length

    sig { params(add_sig_templates: T::Boolean, group_nodes: T::Boolean, max_line_length: T.nilable(Integer), nest_singleton_methods: T::Boolean, nest_non_public_members: T::Boolean, sort_nodes: T::Boolean).void }
    def initialize(add_sig_templates: false, group_nodes: false, max_line_length: nil, nest_singleton_methods: false, nest_non_public_members: false, sort_nodes: false); end

    sig { params(file: RBI::File).returns(String) }
    def print_file(file); end

    sig { params(file: RBI::File).void }
    def format_file(file); end

    sig { params(tree: RBI::Tree).void }
    def format_tree(tree); end
  end
end
