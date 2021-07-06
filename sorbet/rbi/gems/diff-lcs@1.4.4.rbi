# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `diff-lcs` gem.
# Please instead update this file by running `bin/tapioca sync`.

# typed: true

module Diff; end

module Diff::LCS
  def diff(other, callbacks = T.unsafe(nil), &block); end
  def lcs(other, &block); end
  def patch(patchset); end
  def patch!(patchset); end
  def patch_me(patchset); end
  def sdiff(other, callbacks = T.unsafe(nil), &block); end
  def traverse_balanced(other, callbacks = T.unsafe(nil), &block); end
  def traverse_sequences(other, callbacks = T.unsafe(nil), &block); end
  def unpatch(patchset); end
  def unpatch!(patchset); end
  def unpatch_me(patchset); end

  class << self
    def LCS(seq1, seq2, &block); end
    def callbacks_for(callbacks); end
    def diff(seq1, seq2, callbacks = T.unsafe(nil), &block); end
    def lcs(seq1, seq2, &block); end
    def patch(src, patchset, direction = T.unsafe(nil)); end
    def patch!(src, patchset); end
    def sdiff(seq1, seq2, callbacks = T.unsafe(nil), &block); end
    def traverse_balanced(seq1, seq2, callbacks = T.unsafe(nil)); end
    def traverse_sequences(seq1, seq2, callbacks = T.unsafe(nil)); end
    def unpatch!(src, patchset); end

    private

    def diff_traversal(method, seq1, seq2, callbacks, &block); end
  end
end

Diff::LCS::BalancedCallbacks = Diff::LCS::DefaultCallbacks

class Diff::LCS::Block
  def initialize(chunk); end

  def changes; end
  def diff_size; end
  def insert; end
  def op; end
  def remove; end
end

class Diff::LCS::Change
  include ::Comparable

  def initialize(*args); end

  def <=>(other); end
  def ==(other); end
  def action; end
  def adding?; end
  def changed?; end
  def deleting?; end
  def element; end
  def finished_a?; end
  def finished_b?; end
  def inspect(*_args); end
  def position; end
  def to_a; end
  def to_ary; end
  def unchanged?; end

  class << self
    def from_a(arr); end
    def valid_action?(action); end
  end
end

Diff::LCS::Change::IntClass = Integer
Diff::LCS::Change::VALID_ACTIONS = T.let(T.unsafe(nil), Array)

class Diff::LCS::ContextChange < ::Diff::LCS::Change
  def initialize(*args); end

  def <=>(other); end
  def ==(other); end
  def new_element; end
  def new_position; end
  def old_element; end
  def old_position; end
  def to_a; end
  def to_ary; end

  class << self
    def from_a(arr); end
    def simplify(event); end
  end
end

class Diff::LCS::ContextDiffCallbacks < ::Diff::LCS::DiffCallbacks
  def change(event); end
  def discard_a(event); end
  def discard_b(event); end
end

class Diff::LCS::DefaultCallbacks
  class << self
    def change(event); end
    def discard_a(event); end
    def discard_b(event); end
    def match(event); end
  end
end

class Diff::LCS::DiffCallbacks
  def initialize; end

  def diffs; end
  def discard_a(event); end
  def discard_b(event); end
  def finish; end
  def match(_event); end

  private

  def finish_hunk; end
end

class Diff::LCS::Hunk
  def initialize(data_old, data_new, piece, flag_context, file_length_difference); end

  def blocks; end
  def diff(format, last = T.unsafe(nil)); end
  def end_new; end
  def end_old; end
  def file_length_difference; end
  def flag_context; end
  def flag_context=(context); end
  def merge(hunk); end
  def missing_last_newline?(data); end
  def overlaps?(hunk); end
  def start_new; end
  def start_old; end
  def unshift(hunk); end

  private

  def context_diff(last = T.unsafe(nil)); end
  def context_range(mode, op, last = T.unsafe(nil)); end
  def ed_diff(format, _last = T.unsafe(nil)); end
  def encode(literal, target_encoding = T.unsafe(nil)); end
  def encode_as(string, *args); end
  def old_diff(_last = T.unsafe(nil)); end
  def unified_diff(last = T.unsafe(nil)); end
  def unified_range(mode, last); end
end

Diff::LCS::Hunk::ED_DIFF_OP_ACTION = T.let(T.unsafe(nil), Hash)
Diff::LCS::Hunk::OLD_DIFF_OP_ACTION = T.let(T.unsafe(nil), Hash)

module Diff::LCS::Internals
  class << self
    def analyze_patchset(patchset, depth = T.unsafe(nil)); end
    def intuit_diff_direction(src, patchset, limit = T.unsafe(nil)); end
    def lcs(a, b); end

    private

    def inverse_vector(a, vector); end
    def position_hash(enum, interval); end
    def replace_next_larger(enum, value, last_index = T.unsafe(nil)); end
  end
end

class Diff::LCS::SDiffCallbacks
  def initialize; end

  def change(event); end
  def diffs; end
  def discard_a(event); end
  def discard_b(event); end
  def match(event); end
end

Diff::LCS::SequenceCallbacks = Diff::LCS::DefaultCallbacks
Diff::LCS::VERSION = T.let(T.unsafe(nil), String)
