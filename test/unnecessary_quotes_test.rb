# frozen_string_literal: true

require "test_helper"

class UnnecessaryQuotesTest < Minitest::Test
  SAFE_VALUES = ["word", "two words", "日本語", "100% 完了", "it's"].freeze
  UNSAFE_VALUES = [
    "yes", "no", "on", "off", "y", "n", "3", "1.0", "0x1F", "007", "12:30", "2025-12-01",
    "~", "null", "%{count}", "%{count}件", "* foo", "- foo", "@user", "`cmd", "|pipe", ">gt",
    "&anchor", "!tag", "?que", "", " leading", "trailing ", "no #hash"
  ].freeze

  def test_removes_safe_single_and_double_quotes
    source = SAFE_VALUES.each_with_index.map do |value, index|
      escaped = value.gsub("'", "''")
      "key#{index}: '#{escaped}'"
    end.join("\n") << "\n"
    expected = SAFE_VALUES.each_with_index.map { |value, index| "key#{index}: #{value}" }.join("\n") << "\n"

    assert_equal expected, process(source)
  end

  def test_preserves_quotes_for_values_psych_does_not_emit_as_plain
    source = UNSAFE_VALUES.each_with_index.map do |value, index|
      "key#{index}: #{Psych.dump(value).delete_prefix("--- ").chomp}"
    end.join("\n") << "\n"

    assert_equal source, process(source)
  end

  def test_handles_japanese_duplicate_values_flow_style_and_inline_comments
    source = <<~YAML
      日本語:
        key: "value" # comment
      flow: ['same', 'same']
    YAML
    expected = <<~YAML
      日本語:
        key: value # comment
      flow: [same, same]
    YAML

    assert_equal expected, process(source)
  end

  def test_runs_outside_a_block_scalar_while_line_rules_are_skipped
    source = "name: \"value\"  \nbody: |\n  text  \n"

    assert_equal "name: value  \nbody: |\n  text  \n", process(source)
  end

  def test_is_idempotent
    formatted = process("key: \"value\"\n")

    assert_equal formatted, process(formatted)
  end

  private

  def process(source)
    rule = Yamlfmt::Rule::UnnecessaryQuotes.new
    Yamlfmt::Processor.new.call(source, rules: [rule]).formatted_source
  end
end
