# frozen_string_literal: true

module Yamlfmt
  class Processor
    Result = Data.define(:document, :source, :formatted_source, :findings, :warnings) do
      def changed?
        source != formatted_source
      end
    end

    def initialize(corrector: Corrector.new, validator: SafetyValidator.new)
      @corrector = corrector
      @validator = validator
    end

    def call(source, path: "<unknown>", rules: default_rules)
      document = Document.new(source, path:)
      findings = rules.flat_map { |rule| rule.call(document) }.freeze
      formatted_source = @corrector.call(source, findings)
      @validator.call(document, formatted_source) if formatted_source != source
      warnings = block_scalar_warnings(document, rules).freeze

      Result.new(document:, source:, formatted_source:, findings:, warnings:)
    end

    private

    def default_rules
      Rule::Registry.rules.map(&:new)
    end

    def block_scalar_warnings(document, rules)
      return [] unless document.block_scalar?
      return [] unless rules.any? { |rule| rule.is_a?(Rule::LineBased) }

      ["line-based rules were skipped because the file contains a block scalar"]
    end
  end
end
