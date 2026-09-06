# frozen_string_literal: true

module Yamlfmt
  module Rule
    class UnnecessaryQuotes < AstBased
      QUOTED_STYLES = [Psych::Nodes::Scalar::SINGLE_QUOTED, Psych::Nodes::Scalar::DOUBLE_QUOTED].freeze
      FLOW_INDICATORS = /[\[\]{},]/

      rule_id "unnecessary-quotes"
      priority 400

      def call(document)
        check_tree(document.ast, document, flow_context: false, findings: [])
      end

      def check_node(node, document, flow_context: false)
        return unless node.is_a?(Psych::Nodes::Scalar)
        return unless QUOTED_STYLES.include?(node.style)
        return unless can_unquote?(node.value, flow_context:)

        range = document.range_for(node)
        return unless range

        correction(range, "unnecessary quotes detected", node.value)
      end

      private

      def check_tree(node, document, flow_context:, findings:)
        return findings unless node

        findings.concat(Array(check_node(node, document, flow_context:)))
        child_flow_context = flow_context || flow_collection?(node)
        Array(node.children).each do |child|
          check_tree(child, document, flow_context: child_flow_context, findings:)
        end
        findings
      end

      def can_unquote?(value, flow_context:)
        return false unless value.is_a?(String) && Psych.dump(value) == "--- #{value}\n"

        !flow_context || !value.match?(FLOW_INDICATORS)
      end

      def flow_collection?(node)
        (node.is_a?(Psych::Nodes::Sequence) && node.style == Psych::Nodes::Sequence::FLOW) ||
          (node.is_a?(Psych::Nodes::Mapping) && node.style == Psych::Nodes::Mapping::FLOW)
      end
    end

    Registry.register(UnnecessaryQuotes)
  end
end
