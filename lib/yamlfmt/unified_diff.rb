# frozen_string_literal: true

module Yamlfmt
  class UnifiedDiff
    CONTEXT_LINES = 3
    MAX_LCS_CELLS = 1_000_000

    Record = Data.define(:type, :line)

    def call(before, after, path:)
      return "" if before == after

      records = diff_records(split_lines(before), split_lines(after))
      hunks = hunk_ranges(records)

      output = "--- #{path}\n+++ #{path}\n"
      hunks.each { |range| append_hunk(output, records, range) }
      output
    end

    private

    def split_lines(source)
      source.lines(chomp: false)
    end

    def diff_records(before, after)
      return fallback_records(before, after) if before.length * after.length > MAX_LCS_CELLS

      table = lcs_table(before, after)
      records = []
      before_index = 0
      after_index = 0

      while before_index < before.length && after_index < after.length
        if before[before_index] == after[after_index]
          records << Record.new(type: :equal, line: before[before_index])
          before_index += 1
          after_index += 1
        elsif table[before_index + 1][after_index] >= table[before_index][after_index + 1]
          records << Record.new(type: :delete, line: before[before_index])
          before_index += 1
        else
          records << Record.new(type: :insert, line: after[after_index])
          after_index += 1
        end
      end

      before.drop(before_index).each { |line| records << Record.new(type: :delete, line:) }
      after.drop(after_index).each { |line| records << Record.new(type: :insert, line:) }
      records
    end

    def lcs_table(before, after)
      table = Array.new(before.length + 1) { Array.new(after.length + 1, 0) }

      (before.length - 1).downto(0) do |before_index|
        (after.length - 1).downto(0) do |after_index|
          table[before_index][after_index] = if before[before_index] == after[after_index]
            table[before_index + 1][after_index + 1] + 1
          else
            [table[before_index + 1][after_index], table[before_index][after_index + 1]].max
          end
        end
      end

      table
    end

    def fallback_records(before, after)
      prefix_length = common_prefix_length(before, after)
      suffix_length = common_suffix_length(before.drop(prefix_length), after.drop(prefix_length))

      prefix = before.first(prefix_length).map { |line| Record.new(type: :equal, line:) }
      deleted = before[prefix_length, before.length - prefix_length - suffix_length].map { |line| Record.new(type: :delete, line:) }
      inserted = after[prefix_length, after.length - prefix_length - suffix_length].map { |line| Record.new(type: :insert, line:) }
      suffix = before.last(suffix_length).map { |line| Record.new(type: :equal, line:) }
      prefix + deleted + inserted + suffix
    end

    def common_prefix_length(before, after)
      limit = [before.length, after.length].min
      (0...limit).find { |index| before[index] != after[index] } || limit
    end

    def common_suffix_length(before, after)
      limit = [before.length, after.length].min
      (0...limit).find { |index| before[-index - 1] != after[-index - 1] } || limit
    end

    def hunk_ranges(records)
      changes = records.each_index.reject { |index| records[index].type == :equal }
      ranges = changes.map do |index|
        [index - CONTEXT_LINES, 0].max..[index + CONTEXT_LINES, records.length - 1].min
      end

      ranges.each_with_object([]) do |range, merged|
        if merged.last && range.begin <= merged.last.end + 1
          merged[-1] = merged.last.begin..[merged.last.end, range.end].max
        else
          merged << range
        end
      end
    end

    def append_hunk(output, records, range)
      before_start = 1 + records.first(range.begin).count { |record| record.type != :insert }
      after_start = 1 + records.first(range.begin).count { |record| record.type != :delete }
      hunk = records[range]
      before_count = hunk.count { |record| record.type != :insert }
      after_count = hunk.count { |record| record.type != :delete }
      before_start -= 1 if before_count.zero?
      after_start -= 1 if after_count.zero?

      output << "@@ -#{before_start},#{before_count} +#{after_start},#{after_count} @@\n"
      hunk.each { |record| append_record(output, record) }
    end

    def append_record(output, record)
      prefix = {equal: " ", delete: "-", insert: "+"}.fetch(record.type)
      ending = record.line[/\r\n|\n|\r\z/]
      content = ending ? record.line.byteslice(0, record.line.bytesize - ending.bytesize) : record.line
      output << prefix << content << "\n"
      output << "\\ No newline at end of file\n" unless ending
    end
  end
end
