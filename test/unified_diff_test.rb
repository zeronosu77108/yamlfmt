# frozen_string_literal: true

require "test_helper"

class UnifiedDiffTest < Minitest::Test
  def test_renders_separate_hunks_with_context
    before = (1..12).map { |number| "line #{number}\n" }.join
    after = before.sub("line 2\n", "changed 2\n").sub("line 11\n", "changed 11\n")
    output = Yamlfmt::UnifiedDiff.new.call(before, after, path: "example.yml")

    assert_equal 2, output.scan(/^@@/).length
    assert_includes output, "-line 2\n+changed 2\n"
    assert_includes output, "-line 11\n+changed 11\n"
  end

  def test_marks_a_missing_final_newline
    output = Yamlfmt::UnifiedDiff.new.call("key: value", "key: value\n", path: "example.yml")

    assert_includes output, "\\ No newline at end of file"
  end

  def test_returns_an_empty_string_without_changes
    assert_equal "", Yamlfmt::UnifiedDiff.new.call("same\n", "same\n", path: "example.yml")
  end
end
