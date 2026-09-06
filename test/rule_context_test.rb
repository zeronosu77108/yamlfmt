# frozen_string_literal: true

require "test_helper"

class RuleContextTest < Minitest::Test
  def test_line_context_exposes_neighbors_and_position
    rule = Class.new(Yamlfmt::Rule::LineBased) do
      attr_reader :seen

      def initialize(...)
        super
        @seen = []
      end

      def check_line(context)
        @seen << {
          content: context.line.content,
          previous: context.previous_line&.content,
          next: context.next_line&.content,
          first: context.first?,
          last: context.last?,
          index: context.index
        }
        nil
      end
    end.new
    document = Yamlfmt::Document.new("first: 1\nsecond: 2\nthird: 3\n")

    rule.call(document)

    assert_equal [
      {content: "first: 1", previous: nil, next: "second: 2", first: true, last: false, index: 0},
      {content: "second: 2", previous: "first: 1", next: "third: 3", first: false, last: false, index: 1},
      {content: "third: 3", previous: "second: 2", next: nil, first: false, last: true, index: 2}
    ], rule.seen
  end

  def test_ast_context_marks_flow_collections_and_compact_mapping_keys
    rule = Class.new(Yamlfmt::Rule::AstBased) do
      attr_reader :seen

      def initialize(...)
        super
        @seen = []
      end

      def check_node(context)
        return unless context.node.is_a?(Psych::Nodes::Scalar)

        @seen << {
          value: context.node.value,
          flow: context.flow?,
          flow_mapping_key: context.flow_mapping_key?,
          parent: context.parent.class
        }
        nil
      end
    end.new
    document = Yamlfmt::Document.new(<<~YAML)
      block: "outside"
      sequence: ["inside"]
      mapping: {"key": "value"}
    YAML

    rule.call(document)

    assert_equal [
      {value: "block", flow: false, flow_mapping_key: false, parent: Psych::Nodes::Mapping},
      {value: "outside", flow: false, flow_mapping_key: false, parent: Psych::Nodes::Mapping},
      {value: "sequence", flow: false, flow_mapping_key: false, parent: Psych::Nodes::Mapping},
      {value: "inside", flow: true, flow_mapping_key: false, parent: Psych::Nodes::Sequence},
      {value: "mapping", flow: false, flow_mapping_key: false, parent: Psych::Nodes::Mapping},
      {value: "key", flow: true, flow_mapping_key: true, parent: Psych::Nodes::Mapping},
      {value: "value", flow: true, flow_mapping_key: false, parent: Psych::Nodes::Mapping}
    ], rule.seen
  end
end
