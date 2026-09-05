# frozen_string_literal: true

require "test_helper"

class LineRulesTest < Minitest::Test
  def test_removes_spaces_and_tabs_at_line_endings
    source = "日本語: value  \nnext: value\t\r\n"

    assert_equal "日本語: value\nnext: value\r\n", format_source(source, only: "trailing-whitespace")
  end

  def test_compresses_internal_and_leading_blank_lines
    source = "\n\nfirst: value\n \n  \nsecond: value\n\n"

    assert_equal "\nfirst: value\n \nsecond: value\n\n", format_source(source, only: "blank-lines")
    assert_equal "first: value\nsecond: value\n\n", format_source(source, only: "blank-lines", config: {max: 0})
  end

  def test_adds_a_final_newline_using_the_existing_style
    source = "first: value\r\nsecond: value"

    assert_equal "first: value\r\nsecond: value\r\n", format_source(source, only: "final-newline")
  end

  def test_removes_extra_final_lines
    source = "first: value\n \n\n"

    assert_equal "first: value\n", format_source(source, only: "final-newline")
  end

  def test_preserves_an_empty_file_and_clears_a_whitespace_only_file
    assert_equal "", format_source("", only: "final-newline")
    assert_equal "", format_source("  \n", only: "final-newline")
  end

  def test_line_rules_are_skipped_for_an_entire_block_scalar_file
    source = "outside: value  \nbody: |\n  text  \n"

    assert_equal source, format_source(source)
  end

  def test_all_line_rules_are_idempotent_together
    source = "\n\nfirst: value  \n \n  \nsecond: value\t"
    formatted = format_source(source)

    assert_equal "\nfirst: value\n\nsecond: value\n", formatted
    assert_equal formatted, format_source(formatted)
  end

  private

  def format_source(source, only: nil, config: {})
    document = Yamlfmt::Document.new(source)
    rules = if only
      [[Yamlfmt::Rule::Registry.fetch(only), config]]
    else
      Yamlfmt::Rule::Registry.rules.map { |rule| [rule, {}] }
    end
    findings = rules.flat_map { |rule, rule_config| rule.new(rule_config).call(document) }
    Yamlfmt::Corrector.new.call(source, findings)
  end
end
