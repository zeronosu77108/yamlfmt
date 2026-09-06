# frozen_string_literal: true

module Yamlfmt
  module Rule
    class LineBased < Base
      Context = Data.define(:line, :index, :lines, :document) do
        def previous_line
          index.positive? ? lines[index - 1] : nil
        end

        def next_line
          lines[index + 1]
        end

        def first?
          index.zero?
        end

        def last?
          index == lines.length - 1
        end
      end

      def call(document)
        return [] if document.block_scalar?

        each_context(document).flat_map do |context|
          Array(check_line(context))
        end
      end

      def check_line(_context)
        raise NotImplementedError
      end

      private

      def each_context(document, &block)
        return enum_for(__method__, document) unless block

        lines = document.lines
        lines.each_with_index do |line, index|
          yield Context.new(line:, index:, lines:, document:)
        end
      end
    end
  end
end
