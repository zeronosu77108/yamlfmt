# frozen_string_literal: true

module Yamlfmt
  SourceRange = Data.define(:start_offset, :end_offset) do
    def initialize(start_offset:, end_offset:)
      unless start_offset.is_a?(Integer) && end_offset.is_a?(Integer) &&
          start_offset >= 0 && end_offset >= start_offset
        raise ArgumentError, "source range must be a non-negative half-open byte range"
      end

      super
    end

    def length
      end_offset - start_offset
    end

    def empty?
      length.zero?
    end

    def cover?(other)
      start_offset <= other.start_offset && end_offset >= other.end_offset
    end

    def overlaps?(other)
      if empty? && other.empty?
        start_offset == other.start_offset
      elsif empty?
        start_offset > other.start_offset && start_offset < other.end_offset
      elsif other.empty?
        other.start_offset > start_offset && other.start_offset < end_offset
      else
        start_offset < other.end_offset && other.start_offset < end_offset
      end
    end
  end
end
