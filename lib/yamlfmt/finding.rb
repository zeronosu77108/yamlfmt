# frozen_string_literal: true

module Yamlfmt
  Finding = Data.define(:rule_id, :range, :message, :edit) do
    def initialize(rule_id:, range:, message:, edit: nil)
      raise ArgumentError, "range must be a SourceRange" unless range.is_a?(SourceRange)
      raise ArgumentError, "edit must be an Edit or nil" unless edit.nil? || edit.is_a?(Edit)

      super
    end

    def autocorrectable?
      !edit.nil?
    end
  end
end
