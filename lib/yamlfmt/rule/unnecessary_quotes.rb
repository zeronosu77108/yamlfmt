# frozen_string_literal: true

module Yamlfmt
  module Rule
    class UnnecessaryQuotes < AstBased
      QUOTED_STYLES = [Psych::Nodes::Scalar::SINGLE_QUOTED, Psych::Nodes::Scalar::DOUBLE_QUOTED].freeze
      FLOW_INDICATORS = /[\[\]{},]/

      rule_id "unnecessary-quotes"
      priority 400

      def call(document)
        check_tree(document.ast, document, flow_context: false, flow_mapping_key: false, findings: [])
      end

      def check_node(node, document, flow_context: false, flow_mapping_key: false)
        return unless node.is_a?(Psych::Nodes::Scalar)
        return unless QUOTED_STYLES.include?(node.style)
        return unless can_unquote?(node.value, flow_context:)

        range = document.range_for(node)
        return unless range
        return if flow_mapping_key && missing_flow_key_separation?(document.source, range)

        correction(range, "unnecessary quotes detected", node.value)
      end

      private

      def check_tree(node, document, flow_context:, flow_mapping_key:, findings:)
        return findings unless node

        findings.concat(Array(check_node(node, document, flow_context:, flow_mapping_key:)))
        child_flow_context = flow_context || flow_collection?(node)
        Array(node.children).each_with_index do |child, index|
          child_is_flow_mapping_key = flow_mapping?(node) && index.even?
          check_tree(
            child,
            document,
            flow_context: child_flow_context,
            flow_mapping_key: child_is_flow_mapping_key,
            findings:
          )
        end
        findings
      end

      def can_unquote?(value, flow_context:)
        return false unless value.is_a?(String) && Psych.dump(value) == "--- #{value}\n"

        !flow_context || !value.match?(FLOW_INDICATORS)
      end

      def flow_collection?(node)
        (node.is_a?(Psych::Nodes::Sequence) && node.style == Psych::Nodes::Sequence::FLOW) ||
          flow_mapping?(node)
      end

      def flow_mapping?(node)
        node.is_a?(Psych::Nodes::Mapping) && node.style == Psych::Nodes::Mapping::FLOW
      end

      def missing_flow_key_separation?(source, range)
        offset = range.end_offset
        offset += 1 while [9, 32].include?(source.getbyte(offset))
        return false unless source.getbyte(offset) == 58

        following = source.getbyte(offset + 1)
        following && ![9, 10, 13, 32].include?(following)
      end
    end

    Registry.register(UnnecessaryQuotes)
  end
end
