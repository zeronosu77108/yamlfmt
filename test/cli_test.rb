# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "stringio"
require "tmpdir"
require "test_helper"

class CLITest < Minitest::Test
  class TTYStringIO < StringIO
    def tty?
      true
    end
  end

  def setup
    @directory = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_check_mode_reports_findings_without_rewriting
    path = write("example.yml", "key: \"value\"  ")

    status, stdout, stderr = run_cli([])

    assert_equal 1, status
    assert_equal "key: \"value\"  ", File.read(path)
    assert_includes stdout, "example.yml:1:"
    assert_includes stdout, "trailing-whitespace"
    assert_includes stdout, "final-newline"
    assert_includes stdout, "unnecessary-quotes"
    assert stdout.end_with?("1 file inspected, 3 issues found, 3 autocorrectable\n"), stdout
    assert_empty stderr
  end

  def test_fix_mode_rewrites_files_and_returns_success
    path = write("example.yml", "key: \"value\"  ")

    status, stdout, = run_cli(["--fix"])

    assert_equal 0, status
    assert_equal "key: value\n", File.read(path)
    assert stdout.end_with?("1 file inspected, 3 issues found, 3 corrected in 1 file\n"), stdout
  end

  def test_fix_mode_reports_issues_that_remain
    path = write("example.yml", "one: value\n")
    findings = [
      finding("correctable", 0, 3, "ONE"),
      finding("report-only", 5, 10)
    ]
    processor = processor_returning("ONE: value\n", findings)

    status, stdout, = run_cli(["--fix"], processor:)

    assert_equal 1, status
    assert_equal "ONE: value\n", File.read(path)
    assert stdout.end_with?("1 file inspected, 2 issues found, 1 corrected in 1 file, 1 issue remains\n"), stdout
  end

  def test_diff_mode_prints_a_unified_diff_without_rewriting
    path = write("example.yml", "key: \"value\"\n")

    status, stdout, = run_cli(["example.yml", "--diff"])

    assert_equal 1, status
    assert_equal "key: \"value\"\n", File.read(path)
    assert_includes stdout, "--- example.yml\n+++ example.yml\n"
    assert_includes stdout, "-key: \"value\"\n+key: value\n"
    refute_includes stdout, "file inspected"
  end

  def test_check_mode_summarizes_clean_and_empty_targets
    write("example.yml", "key: value\n")

    assert_equal "1 file inspected, no issues found\n", run_cli([])[1]

    Dir.mkdir(File.join(@directory, "empty"))
    assert_equal "0 files inspected, no issues found\n", run_cli(["empty"])[1]
  end

  def test_diff_colors_changes_but_not_file_headers_on_a_terminal
    write("example.yml", "key: \"value\"\n")
    stdout = TTYStringIO.new

    status, output, = run_cli(["--diff"], stdout:)

    assert_equal 1, status
    assert_includes output, "--- example.yml\n+++ example.yml\n"
    refute_includes output, "\e[31m--- example.yml"
    assert_includes output, "\e[31m-key: \"value\"\n\e[0m"
    assert_includes output, "\e[32m+key: value\n\e[0m"
  end

  def test_fix_and_diff_are_mutually_exclusive
    status, _, stderr = run_cli(["--fix", "--diff"])

    assert_equal 1, status
    assert_includes stderr, "--fix and --diff cannot be used together"
  end

  def test_unknown_options_are_errors
    status, _, stderr = run_cli(["--unknown"])

    assert_equal 1, status
    assert_includes stderr, "invalid option"
  end

  def test_zero_targets_succeeds_and_missing_paths_fail
    assert_equal 0, run_cli([]).first
    assert_equal 1, run_cli(["missing"]).first
  end

  def test_direct_files_do_not_need_yaml_extensions
    path = write("config", "key: \"value\"\n")

    assert_equal 0, run_cli(["--fix", "config"]).first
    assert_equal "key: value\n", File.read(path)
  end

  def test_configuration_disables_rules_and_excludes_names
    write(".yamlfmt.yml", <<~YAML)
      rules:
        unnecessary-quotes: false
      exclude:
        - vendor
    YAML
    path = write("example.yml", "key: \"value\"  \n")
    excluded = write("nested/vendor/example.yml", "key: \"value\"  \n")

    assert_equal 0, run_cli(["--fix"]).first
    assert_equal "key: \"value\"\n", File.read(path)
    assert_equal "key: \"value\"  \n", File.read(excluded)
  end

  def test_init_creates_configuration_without_overwriting
    status, stdout, = run_cli(["--init"])

    assert_equal 0, status
    assert_includes stdout, "Created .yamlfmt.yml"
    contents = File.read(File.join(@directory, ".yamlfmt.yml"))
    assert_includes contents, "trailing-whitespace: true"

    assert_equal 1, run_cli(["--init"]).first
    assert_equal contents, File.read(File.join(@directory, ".yamlfmt.yml"))
  end

  def test_init_cannot_be_combined_with_paths
    assert_equal 1, run_cli(["--init", "."]).first
  end

  def test_parse_errors_do_not_prevent_other_files_from_being_fixed
    invalid = write("invalid.yml", "key: [\n")
    valid = write("valid.yml", "key: \"value\"\n")

    status, stdout, stderr = run_cli(["--fix"])

    assert_equal 1, status
    assert_equal "key: [\n", File.read(invalid)
    assert_equal "key: value\n", File.read(valid)
    assert_includes stderr, "invalid.yml:"
    assert stdout.end_with?("2 files inspected, 1 issue found, 1 corrected in 1 file, 1 file failed\n"), stdout
  end

  def test_unsupported_files_fail_without_being_changed
    path = write("documents.yml", "---\none: 1\n---\ntwo: 2\n")

    assert_equal 1, run_cli(["--fix"]).first
    assert_equal "---\none: 1\n---\ntwo: 2\n", File.read(path)
  end

  def test_warns_when_line_rules_are_skipped_for_block_scalars
    write("example.yml", "name: \"value\"  \nbody: |\n  text  \n")

    status, stdout, stderr = run_cli(["--fix"])

    assert_equal 0, status
    assert_includes stderr, "line-based rules were skipped"
    assert stdout.end_with?("1 file inspected, 1 issue found, 1 corrected in 1 file\n"), stdout
  end

  def test_help_and_version_succeed
    assert_includes run_cli(["--help"])[1], "Usage: yamlfmt"
    assert_equal "#{Yamlfmt::VERSION}\n", run_cli(["--version"])[1]
  end

  def test_executable_returns_the_cli_status
    write("example.yml", "key: \"value\"\n")
    executable = File.expand_path("../exe/yamlfmt", __dir__)
    library = File.expand_path("../lib", __dir__)

    _stdout, _stderr, status = Open3.capture3(RbConfig.ruby, "-I#{library}", executable, "example.yml", chdir: @directory)

    assert_equal 1, status.exitstatus
  end

  private

  def run_cli(arguments, stdout: StringIO.new, processor: Yamlfmt::Processor.new)
    stderr = StringIO.new
    status = Yamlfmt::CLI.new(stdout:, stderr:, cwd: @directory, processor:).run(arguments)
    [status, stdout.string, stderr.string]
  end

  def finding(rule_id, start_offset, end_offset, replacement = nil)
    range = Yamlfmt::SourceRange.new(start_offset:, end_offset:)
    edit = Yamlfmt::Edit.new(range:, replacement:) if replacement
    Yamlfmt::Finding.new(rule_id:, range:, message: "message", edit:)
  end

  def processor_returning(formatted_source, findings)
    Object.new.tap do |processor|
      processor.define_singleton_method(:call) do |source, path:, rules:|
        document = Yamlfmt::Document.new(source, path:)
        Yamlfmt::Processor::Result.new(document:, source:, formatted_source:, findings:, warnings: [])
      end
    end
  end

  def write(path, contents)
    absolute = File.join(@directory, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, contents)
    absolute
  end
end
