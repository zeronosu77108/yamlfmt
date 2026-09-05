# frozen_string_literal: true

require "test_helper"

class SourceRangeTest < Minitest::Test
  def test_represents_a_half_open_byte_range
    range = Yamlfmt::SourceRange.new(start_offset: 2, end_offset: 5)

    assert_equal 3, range.length
    refute range.empty?
  end

  def test_rejects_an_inverted_range
    assert_raises(ArgumentError) do
      Yamlfmt::SourceRange.new(start_offset: 3, end_offset: 2)
    end
  end

  def test_adjacent_ranges_do_not_overlap
    left = Yamlfmt::SourceRange.new(start_offset: 0, end_offset: 2)
    right = Yamlfmt::SourceRange.new(start_offset: 2, end_offset: 4)

    refute left.overlaps?(right)
  end
end
