# frozen_string_literal: true

module Yamlfmt
  module Rule
    class LineBased < Base
      def call(document)
        return [] if document.block_scalar?

        document.each_line.flat_map do |line|
          Array(check_line(line, document))
        end
      end

      def check_line(_line, _document)
        raise NotImplementedError
      end
    end
  end
end
