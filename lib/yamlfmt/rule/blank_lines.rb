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

      def call(document)
        return [] if document.block_scalar?

        findings = []
        run_start = nil
        scalar_ranges = scalar_ranges(document)

        document.lines.each_with_index do |line, index|
          if blank?(line) && !inside_scalar?(line, scalar_ranges)
            run_start ||= index
          elsif run_start
            finding = finding_for_run(document.lines, run_start, index)
            findings << finding if finding
            run_start = nil
          end
        end

        findings
      end

      private

      def blank?(line)
        line.content.match?(/\A[ \t]*\z/)
      end

      def scalar_ranges(document)
        document.each_node.filter_map do |node|
          document.range_for(node) if node.is_a?(Psych::Nodes::Scalar)
        end
      end

      def inside_scalar?(line, ranges)
        ranges.any? do |range|
          range.start_offset < line.start_offset && line.start_offset < range.end_offset
        end
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
