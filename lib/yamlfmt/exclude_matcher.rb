# frozen_string_literal: true

require "pathname"

module Yamlfmt
  class ExcludeMatcher
    FLAGS = File::FNM_PATHNAME | File::FNM_DOTMATCH | File::FNM_EXTGLOB

    def initialize(root:, patterns:)
      @root = Pathname(File.expand_path(root))
      @patterns = patterns
    end

    def excluded?(path)
      relative = relative_path(path)
      return false unless relative

      components = relative.split("/")
      @patterns.any? { |pattern| match?(pattern, relative, components) }
    end

    private

    def relative_path(path)
      relative = Pathname(File.expand_path(path)).relative_path_from(@root).to_s
      return if relative == ".." || relative.start_with?("../")

      relative
    rescue ArgumentError
      nil
    end

    def match?(pattern, relative, components)
      if pattern.include?("/")
        path_pattern_match?(pattern, relative)
      elsif glob?(pattern)
        components.any? { |component| File.fnmatch?(pattern, component, FLAGS) }
      else
        components.include?(pattern)
      end
    end

    def path_pattern_match?(pattern, relative)
      if pattern.end_with?("/**")
        path_or_ancestor_match?(pattern.delete_suffix("/**"), relative)
      elsif glob?(pattern)
        path_or_ancestor_match?(pattern, relative)
      else
        relative == pattern || relative.start_with?("#{pattern}/")
      end
    end

    def path_or_ancestor_match?(pattern, relative)
      components = relative.split("/")
      components.each_index.any? do |index|
        ancestor = components.first(index + 1).join("/")
        File.fnmatch?(pattern, ancestor, FLAGS)
      end
    end

    def glob?(pattern)
      pattern.match?(/[*?]/)
    end
  end
end
