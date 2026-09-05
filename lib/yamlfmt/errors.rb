# frozen_string_literal: true

module Yamlfmt
  class Error < StandardError; end

  class ParseError < Error; end
  class UnsupportedFileError < Error; end
  class ValidationError < Error; end

  class ConflictError < Error
    attr_reader :findings

    def initialize(findings)
      @findings = findings.freeze
      rule_ids = findings.map(&:rule_id).uniq.join(", ")
      super("overlapping edits from: #{rule_ids}")
    end
  end
end
