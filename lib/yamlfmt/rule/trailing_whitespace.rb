# frozen_string_literal: true

module Yamlfmt
  module Rule
    class TrailingWhitespace < LineBased
      rule_id "trailing-whitespace"
      priority 100

      def check_line(line, document)
        whitespace = line.content[/[ \t]+\z/]
        return unless whitespace

        ws_start = line.content.bytesize - whitespace.bytesize
        removable_start = removable_trailing_start(line, ws_start, double_quoted_scalar_ranges(document))
        return if removable_start >= line.content.bytesize

        range = SourceRange.new(
          start_offset: line.start_offset + removable_start,
          end_offset: line.start_offset + line.content.bytesize
        )
        correction(range, "trailing whitespace detected", "")
      end

      private

      def double_quoted_scalar_ranges(document)
        document.each_node.filter_map do |node|
          next unless node.is_a?(Psych::Nodes::Scalar)
          next unless node.style == Psych::Nodes::Scalar::DOUBLE_QUOTED

          document.range_for(node)
        end
      end

      def removable_trailing_start(line, ws_start, scalar_ranges)
        removable_start = ws_start
        while removable_start < line.content.bytesize
          byte = line.content.getbyte(removable_start)
          break unless byte == 32 || byte == 9

          offset = line.start_offset + removable_start
          inside_scalar = scalar_ranges.any? { |range| range.start_offset <= offset && offset < range.end_offset }
          break unless inside_scalar && escaped_whitespace?(line.content, removable_start)

          removable_start += 1
        end
        removable_start
      end

      def escaped_whitespace?(content, byte_index)
        backslashes = 0
        position = byte_index - 1
        while position >= 0 && content.getbyte(position) == 92
          backslashes += 1
          position -= 1
        end
        backslashes.odd?
      end
    end

    Registry.register(TrailingWhitespace)
  end
end
