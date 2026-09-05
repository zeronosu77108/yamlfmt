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

      unique_pairs.combination(2) do |left, right|
        left_finding, left_edit = left
        right_finding, right_edit = right
        next unless left_edit.range.overlaps?(right_edit.range)

        if redundant_deletion?(left_edit, right_edit)
          redundant[right.object_id] = true
        elsif redundant_deletion?(right_edit, left_edit)
          redundant[left.object_id] = true
        else
          raise ConflictError, [left_finding, right_finding]
        end
      end

      unique_pairs.reject { |pair| redundant[pair.object_id] }.map(&:last)
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
