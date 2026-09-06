# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "test_helper"

class ConfigTest < Minitest::Test
  def test_uses_defaults_without_a_configuration_file
    Dir.mktmpdir do |directory|
      config = Yamlfmt::Config.load(cwd: directory)

      assert_empty config.exclude
      assert_empty config.warnings
      assert_equal Yamlfmt::Rule::Registry.ids.sort, Yamlfmt::RulePlan.new.call(config).map { |rule| rule.class.rule_id }.sort
    end
  end

  def test_loads_only_the_configuration_in_the_current_directory
    Dir.mktmpdir do |directory|
      nested = File.join(directory, "nested")
      FileUtils.mkdir_p(nested)
      File.write(File.join(directory, ".yamlfmt.yml"), "exclude:\n  - parent\n")

      assert_empty Yamlfmt::Config.load(cwd: nested).exclude
    end
  end

  def test_disables_rules_and_overrides_options
    config = Yamlfmt::Config.new({
      "rules" => {
        "trailing-whitespace" => false,
        "blank-lines" => {"max" => 2}
      }
    })
    rules = Yamlfmt::RulePlan.new.call(config)

    refute_includes rules.map { |rule| rule.class.rule_id }, "trailing-whitespace"
    assert_equal 2, rules.find { |rule| rule.is_a?(Yamlfmt::Rule::BlankLines) }.config.fetch(:max)
  end

  def test_warns_about_unknown_keys_rules_and_options
    config = Yamlfmt::Config.new({
      "unknown" => true,
      "rules" => {
        "missing-rule" => true,
        "blank-lines" => {"missing-option" => 1}
      }
    })

    assert_equal [
      "unknown configuration key: unknown",
      "unknown rule: missing-rule",
      "unknown option for blank-lines: missing-option"
    ], config.warnings
  end

  def test_rejects_invalid_rule_values
    assert_raises(Yamlfmt::ConfigError) do
      Yamlfmt::Config.new({"rules" => {"blank-lines" => "enabled"}})
    end
  end

  def test_rejects_invalid_known_options_when_building_the_rule_plan
    config = Yamlfmt::Config.new({"rules" => {"blank-lines" => {"max" => -1}}})

    assert_raises(Yamlfmt::ConfigError) { Yamlfmt::RulePlan.new.call(config) }
  end

  def test_rejects_non_string_rule_option_names
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".yamlfmt.yml"), "rules:\n  blank-lines:\n    1: 2\n")

      error = assert_raises(Yamlfmt::ConfigError) { Yamlfmt::Config.load(cwd: directory) }

      assert_equal "option names for blank-lines must be strings or symbols", error.message
    end
  end

  def test_rejects_unsupported_exclude_patterns
    ["/absolute", "../parent", "!important"].each do |pattern|
      assert_raises(Yamlfmt::ConfigError) do
        Yamlfmt::Config.new({"exclude" => [pattern]})
      end
    end
  end

  def test_wraps_invalid_yaml
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, ".yamlfmt.yml"), "exclude: [\n")

      assert_raises(Yamlfmt::ConfigError) { Yamlfmt::Config.load(cwd: directory) }
    end
  end
end
