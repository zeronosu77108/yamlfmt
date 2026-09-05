# frozen_string_literal: true

module Yamlfmt
  module Rule
    class FinalNewline < LineBased
      rule_id "final-newline"
      priority 300

      def call(document)
        return [] if document.source.empty? || document.block_scalar?

        last_content_line = document.lines.reverse_each.find { |line| line.content.match?(/[^ \t]/) }
        return [remove_whitespace_only_source(document)] unless last_content_line

        finding = if last_content_line.ending.empty?
          add_final_newline(document)
        else
          remove_extra_lines(document, last_content_line)
        end

        finding ? [finding] : []
      end

      private

      def remove_whitespace_only_source(document)
        range = SourceRange.new(start_offset: 0, end_offset: document.source.bytesize)
        correction(range, "whitespace-only file detected", "")
      end

      def add_final_newline(document)
        offset = document.source.bytesize
        range = SourceRange.new(start_offset: offset, end_offset: offset)
        correction(range, "final newline missing", document.preferred_line_ending)
      end

      def remove_extra_lines(document, last_content_line)
        start_offset = last_content_line.start_offset + last_content_line.text.bytesize
        return if start_offset == document.source.bytesize

        range = SourceRange.new(start_offset:, end_offset: document.source.bytesize)
        correction(range, "extra final newlines detected", "")
      end
    end

    Registry.register(FinalNewline)
  end
end
