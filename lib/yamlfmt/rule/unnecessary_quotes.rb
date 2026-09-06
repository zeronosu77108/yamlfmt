# frozen_string_literal: true

module Yamlfmt
  module Rule
    class UnnecessaryQuotes < AstBased
      QUOTED_STYLES = [Psych::Nodes::Scalar::SINGLE_QUOTED, Psych::Nodes::Scalar::DOUBLE_QUOTED].freeze
      FLOW_INDICATORS = /[\[\]{},]/

      rule_id "unnecessary-quotes"
      priority 400

      def check_node(context)
        node = context.node
        return unless node.is_a?(Psych::Nodes::Scalar)
        return unless QUOTED_STYLES.include?(node.style)
        return unless can_unquote?(node.value, in_flow: context.flow?)

        range = context.document.range_for(node)
        return unless range
        return if multiline?(context.document.source, range)
        return if context.flow_mapping_key? && missing_flow_key_separation?(context.document.source, range)

        correction(range, "unnecessary quotes detected", node.value)
      end

      private

      def can_unquote?(value, in_flow:)
        return false unless value.is_a?(String) && Psych.dump(value) == "--- #{value}\n"

        !in_flow || !value.match?(FLOW_INDICATORS)
      end

      def multiline?(source, range)
        source.byteslice(range.start_offset, range.length).match?(/[\r\n]/)
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
