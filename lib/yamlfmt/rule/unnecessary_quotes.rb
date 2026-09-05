# frozen_string_literal: true

module Yamlfmt
  module Rule
    class UnnecessaryQuotes < AstBased
      QUOTED_STYLES = [Psych::Nodes::Scalar::SINGLE_QUOTED, Psych::Nodes::Scalar::DOUBLE_QUOTED].freeze

      rule_id "unnecessary-quotes"
      priority 400

      def check_node(node, document)
        return unless node.is_a?(Psych::Nodes::Scalar)
        return unless QUOTED_STYLES.include?(node.style)
        return unless can_unquote?(node.value)

        range = document.range_for(node)
        return unless range

        correction(range, "unnecessary quotes detected", node.value)
      end

      private

      def can_unquote?(value)
        value.is_a?(String) && Psych.dump(value) == "--- #{value}\n"
      end
    end

    Registry.register(UnnecessaryQuotes)
  end
end
