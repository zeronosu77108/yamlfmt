# frozen_string_literal: true

module Yamlfmt
  module Rule
    class BlankLines < LineBased
      rule_id "blank-lines"
      priority 200
      default_config max: 1

      def self.validate_config(config)
        max = config.fetch(:max)
        return if max.is_a?(Integer) && max >= 0

        raise ConfigError, "blank-lines.max must be a non-negative integer"
      end

      def check_line(context)
        ranges = context.document.scalar_ranges
        line = context.line
        return unless blank?(line) && !inside_scalar?(line, ranges)

        following = context.next_line
        return if following.nil?
        return if blank?(following) && !inside_scalar?(following, ranges)

        finding_for_run(context.lines, run_start(context, ranges), context.index + 1)
      end

      private

      def blank?(line)
        line.content.match?(/\A[ \t]*\z/)
      end

      def inside_scalar?(line, ranges)
        ranges.any? do |range|
          range.start_offset < line.start_offset && line.start_offset < range.end_offset
        end
      end

      def run_start(context, ranges)
        start = context.index
        while start.positive?
          previous = context.lines[start - 1]
          break unless blank?(previous) && !inside_scalar?(previous, ranges)

          start -= 1
        end
        start
      end

      def finding_for_run(lines, run_start, run_end)
        delete_start = run_start + config.fetch(:max)
        return if delete_start >= run_end

        range = SourceRange.new(
          start_offset: lines.fetch(delete_start).start_offset,
          end_offset: lines.fetch(run_end).start_offset
        )
        correction(range, "too many consecutive blank lines", "")
      end
    end

    Registry.register(BlankLines)
  end
end
