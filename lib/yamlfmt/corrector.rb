# frozen_string_literal: true

module Yamlfmt
  class Corrector
    def call(source, findings)
      edits = normalize(findings)
      validate_ranges!(source, edits)

      edits.sort_by { |edit| [edit.range.start_offset, edit.range.end_offset] }.reverse_each.reduce(source.dup) do |result, edit|
        before = result.byteslice(0, edit.range.start_offset)
        after = result.byteslice(edit.range.end_offset, result.bytesize - edit.range.end_offset)
        "#{before}#{edit.replacement}#{after}"
      end
    end

    private

    def normalize(findings)
      pairs = findings.filter_map { |finding| [finding, finding.edit] if finding.edit }
      unique_pairs = pairs.uniq { |_, edit| [edit.range, edit.replacement] }
      redundant = {}

      sorted_pairs = unique_pairs.sort_by { |_, edit| [edit.range.start_offset, edit.range.end_offset] }

      sorted_pairs.each_with_index do |left, index|
        left_finding, left_edit = left
        ((index + 1)...sorted_pairs.length).each do |right_index|
          right = sorted_pairs[right_index]
          right_finding, right_edit = right
          break if past_overlap_window?(left_edit, right_edit)

          next unless left_edit.range.overlaps?(right_edit.range)

          if redundant_deletion?(left_edit, right_edit)
            redundant[right.object_id] = true
          elsif redundant_deletion?(right_edit, left_edit)
            redundant[left.object_id] = true
          else
            raise ConflictError, [left_finding, right_finding]
          end
        end
      end

      unique_pairs.reject { |pair| redundant[pair.object_id] }.map(&:last)
    end

    def past_overlap_window?(left_edit, right_edit)
      left_range = left_edit.range
      right_range = right_edit.range

      if left_range.empty?
        right_range.start_offset > left_range.start_offset
      else
        right_range.start_offset >= left_range.end_offset
      end
    end

    def redundant_deletion?(outer, inner)
      outer.replacement.empty? && inner.replacement.empty? && outer.range.cover?(inner.range)
    end

    def validate_ranges!(source, edits)
      invalid = edits.find { |edit| edit.range.end_offset > source.bytesize }
      raise ArgumentError, "edit range is outside the source" if invalid
    end
  end
end
