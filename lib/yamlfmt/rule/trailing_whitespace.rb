# frozen_string_literal: true

module Yamlfmt
  module Rule
    class TrailingWhitespace < LineBased
      rule_id "trailing-whitespace"
      priority 100

      def check_line(line, _document)
        whitespace = line.content[/[ \t]+\z/]
        return unless whitespace

        range = SourceRange.new(
          start_offset: line.start_offset + line.content.bytesize - whitespace.bytesize,
          end_offset: line.start_offset + line.content.bytesize
        )
        correction(range, "trailing whitespace detected", "")
      end
    end

    Registry.register(TrailingWhitespace)
  end
end
