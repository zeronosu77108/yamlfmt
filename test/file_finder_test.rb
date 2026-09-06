# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "test_helper"

class FileFinderTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    write("one.yml")
    write("nested/two.yaml")
    write("nested/ignored.txt")
    write(".github/workflows/ci.yml")
    write(".git/config.yml")
    write("vendor/package.yml")
    write("nested/node_modules/package.yml")
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_finds_yaml_recursively_including_hidden_directories
    files = finder.call.map { |path| relative(path) }

    assert_equal [".github/workflows/ci.yml", "nested/two.yaml", "one.yml", "vendor/package.yml", "nested/node_modules/package.yml"].sort, files
  end

  def test_always_excludes_git_directories
    refute_includes finder.call, File.join(@directory, ".git/config.yml")
  end

  def test_applies_name_path_and_glob_exclusions
    files = finder(exclude: ["node_modules", "vendor", ".github/**"]).call.map { |path| relative(path) }

    assert_equal ["nested/two.yaml", "one.yml"], files
  end

  def test_accepts_a_direct_file_regardless_of_extension
    path = File.join(@directory, "nested/ignored.txt")

    assert_equal [path], finder.call(["nested/ignored.txt"])
  end

  def test_applies_exclusions_to_a_direct_file
    assert_empty finder(exclude: ["ignored.txt"]).call(["nested/ignored.txt"])
  end

  def test_applies_wildcard_recursive_exclusions_to_discovered_and_direct_paths
    path = write("apps/web/generated/example.yml")
    excluded_finder = finder(exclude: ["apps/*/generated/**"])

    refute_includes excluded_finder.call, path
    assert_empty excluded_finder.call(["apps/web/generated"])
  end

  def test_applies_wildcard_directory_exclusions_to_discovered_and_direct_files
    path = write("apps/web/example.yml")
    excluded_finder = finder(exclude: ["apps/*"])

    refute_includes excluded_finder.call, path
    assert_empty excluded_finder.call(["apps/web/example.yml"])
  end

  def test_deduplicates_overlapping_roots
    paths = finder.call(["one.yml", "."])

    assert_equal paths.uniq, paths
  end

  def test_does_not_follow_symbolic_links
    File.symlink(File.join(@directory, "nested"), File.join(@directory, "linked"))

    refute finder.call.any? { |path| path.include?("linked") }
  end

  def test_rejects_missing_roots
    assert_raises(Yamlfmt::PathError) { finder.call(["missing"]) }
  end

  private

  def finder(exclude: [])
    Yamlfmt::FileFinder.new(cwd: @directory, exclude:)
  end

  def write(path)
    absolute = File.join(@directory, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, "key: value\n")
    absolute
  end

  def relative(path)
    path.delete_prefix("#{@directory}/")
  end
end
