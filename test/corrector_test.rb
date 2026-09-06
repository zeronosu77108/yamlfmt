# frozen_string_literal: true

require "test_helper"

class CorrectorTest < Minitest::Test
  def test_applies_edits_from_the_end_of_the_source
    findings = [
      finding("first", 0, 1, "A"),
      finding("second", 2, 3, "C")
    ]

    assert_equal "AbC", Yamlfmt::Corrector.new.call("abc", findings)
  end

  def test_rejects_overlapping_edits
    findings = [
      finding("outer", 0, 2, "x"),
      finding("inner", 1, 3, "y")
    ]

    error = assert_raises(Yamlfmt::ConflictError) do
      Yamlfmt::Corrector.new.call("abc", findings)
    end

    assert_equal %w[outer inner], error.findings.map(&:rule_id)
  end

  def test_coalesces_a_redundant_deletion
    findings = [
      finding("outer", 0, 3, ""),
      finding("inner", 1, 2, "")
    ]

    assert_equal "d", Yamlfmt::Corrector.new.call("abcd", findings)
  end

  def test_handles_many_disjoint_edits
    findings = 1_000.times.map do |index|
      offset = index * 4
      finding("rule", offset + 2, offset + 3, "")
    end
    source = findings.map { |finding| "a  b" }.join

    assert_equal "a b" * 1_000, Yamlfmt::Corrector.new.call(source, findings)
  end

  def test_rejects_overlapping_zero_width_insertions_at_the_same_offset
    findings = [
      finding("first", 2, 2, "a"),
      finding("second", 2, 2, "b")
    ]

    error = assert_raises(Yamlfmt::ConflictError) do
      Yamlfmt::Corrector.new.call("abc", findings)
    end

    assert_equal %w[first second], error.findings.map(&:rule_id)
  end

  private

  def finding(rule_id, start_offset, end_offset, replacement)
    range = Yamlfmt::SourceRange.new(start_offset:, end_offset:)
    edit = Yamlfmt::Edit.new(range:, replacement:)
    Yamlfmt::Finding.new(rule_id:, range:, message: "message", edit:)
  end
end
