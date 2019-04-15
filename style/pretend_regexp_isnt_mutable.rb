# frozen_string_literal: true

module RuboCop
  module AST
    # Patches rubocop's Node so it considers regexps immutable. They already
    # are *mostly* immutable and we find it more idiomatic to pretend that
    # they are actually immutable.
    class Node
      MUTABLE_LITERALS = remove_const(:MUTABLE_LITERALS) - [:regexp]
      remove_const :IMMUTABLE_LITERALS
      IMMUTABLE_LITERALS = (LITERALS - MUTABLE_LITERALS).freeze
    end
  end
end
