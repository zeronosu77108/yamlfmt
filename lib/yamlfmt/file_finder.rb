# frozen_string_literal: true

require "find"

module Yamlfmt
  class FileFinder
    YAML_EXTENSIONS = %w[.yml .yaml].freeze

    def initialize(cwd: Dir.pwd, exclude: [])
      @cwd = File.expand_path(cwd)
      @exclude_matcher = ExcludeMatcher.new(root: @cwd, patterns: exclude)
    end

    def call(paths = [])
      roots = paths.empty? ? [@cwd] : paths.map { |path| File.expand_path(path, @cwd) }
      files = {}

      roots.each do |root|
        validate_root!(root)
        next if symlink?(root) || always_excluded?(root) || @exclude_matcher.excluded?(root)

        if File.file?(root)
          files[root] = true
        elsif File.directory?(root)
          find_yaml_files(root, files)
        end
      end

      files.keys.sort
    rescue SystemCallError => error
      raise PathError, error.message
    end

    private

    def validate_root!(root)
      return if File.exist?(root)

      raise PathError, "path does not exist: #{root}"
    end

    def find_yaml_files(root, files)
      Find.find(root) do |path|
        if path != root && (symlink?(path) || always_excluded?(path) || @exclude_matcher.excluded?(path))
          Find.prune if File.directory?(path)
          next
        end

        files[path] = true if File.file?(path) && YAML_EXTENSIONS.include?(File.extname(path))
      end
    end

    def symlink?(path)
      File.symlink?(path)
    end

    def always_excluded?(path)
      Pathname(path).each_filename.include?(".git")
    end
  end
end
