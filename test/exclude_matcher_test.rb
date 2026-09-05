# frozen_string_literal: true

require "test_helper"

class ExcludeMatcherTest < Minitest::Test
  ROOT = "/project"

  def test_matches_a_bare_name_at_any_depth
    matcher = matcher("node_modules")

    assert matcher.excluded?("/project/node_modules/package.yml")
    assert matcher.excluded?("/project/apps/web/node_modules/package.yml")
    refute matcher.excluded?("/project/node_modules.yml")
  end

  def test_matches_relative_path_prefixes
    matcher = matcher("config/generated")

    assert matcher.excluded?("/project/config/generated/file.yml")
    refute matcher.excluded?("/project/apps/config/generated/file.yml")
  end

  def test_matches_globs_including_hidden_paths
    matcher = matcher("*.generated.yml", ".cache/**")

    assert matcher.excluded?("/project/config/example.generated.yml")
    assert matcher.excluded?("/project/.cache/nested/example.yml")
    refute matcher.excluded?("/project/config/example.yml")
  end

  def test_does_not_apply_patterns_outside_the_root
    refute matcher("outside.yml").excluded?("/outside.yml")
  end

  private

  def matcher(*patterns)
    Yamlfmt::ExcludeMatcher.new(root: ROOT, patterns:)
  end
end
