# typed: strict
# frozen_string_literal: true

module RBI
  class Formatter
    extend T::Sig

    sig { params(sort_nodes: T::Boolean).returns(T::Boolean) }
    attr_writer :sort_nodes

    sig { returns(T.nilable(Integer)) }
    attr_accessor :max_line_length

    sig do
      params(
        add_sig_templates: T::Boolean,
        group_nodes: T::Boolean,
        max_line_length: T.nilable(Integer),
        nest_singleton_methods: T::Boolean,
        nest_non_public_members: T::Boolean,
        sort_nodes: T::Boolean,
      ).void
    end
    def initialize(
      add_sig_templates: false,
      group_nodes: false,
      max_line_length: nil,
      nest_singleton_methods: false,
      nest_non_public_members: false,
      sort_nodes: false
    )
      @add_sig_templates = add_sig_templates
      @group_nodes = group_nodes
      @max_line_length = max_line_length
      @nest_singleton_methods = nest_singleton_methods
      @nest_non_public_members = nest_non_public_members
      @sort_nodes = sort_nodes
    end

    sig { params(file: RBI::File).returns(String) }
    def print_file(file)
      format_file(file)
      file.string(max_line_length: @max_line_length)
    end

    sig { params(file: RBI::File).void }
    def format_file(file)
      format_tree(file.root)
    end

    sig { params(tree: RBI::Tree).void }
    def format_tree(tree)
      tree.add_sig_templates! if @add_sig_templates
      tree.nest_singleton_methods! if @nest_singleton_methods
      tree.nest_non_public_members! if @nest_non_public_members
      tree.group_nodes! if @group_nodes
      tree.sort_nodes! if @sort_nodes
    end
  end
end
