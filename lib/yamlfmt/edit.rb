# frozen_string_literal: true

module Yamlfmt
  Edit = Data.define(:range, :replacement) do
    def initialize(range:, replacement:)
      raise ArgumentError, "range must be a SourceRange" unless range.is_a?(SourceRange)
      raise ArgumentError, "replacement must be a String" unless replacement.is_a?(String)

      super
    end
  end
end
