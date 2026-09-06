# frozen_string_literal: true

module Yamlfmt
  module Rule
    class AstBased < Base
      Context = Data.define(:node, :document, :parent, :in_flow, :flow_mapping_key) do
        def flow?
          in_flow
        end

        def flow_mapping_key?
          flow_mapping_key
        end
      end

      def call(document)
        each_context(document).flat_map do |context|
          Array(check_node(context))
        end
      end

      def check_node(_context)
        raise NotImplementedError
      end

      private

      def each_context(document, node = document.ast, parent: nil, in_flow: false, flow_mapping_key: false, &block)
        return enum_for(__method__, document, node, parent:, in_flow:, flow_mapping_key:) unless block
        return if node.nil? || node == false

        yield Context.new(node:, document:, parent:, in_flow:, flow_mapping_key:)

        child_in_flow = in_flow || flow_collection?(node)
        Array(node.children).each_with_index do |child, index|
          each_context(
            document,
            child,
            parent: node,
            in_flow: child_in_flow,
            flow_mapping_key: flow_mapping?(node) && index.even?,
            &block
          )
        end
      end

      def flow_collection?(node)
        (node.is_a?(Psych::Nodes::Sequence) && node.style == Psych::Nodes::Sequence::FLOW) ||
          flow_mapping?(node)
      end

      def flow_mapping?(node)
        node.is_a?(Psych::Nodes::Mapping) && node.style == Psych::Nodes::Mapping::FLOW
      end
    end
  end
end
