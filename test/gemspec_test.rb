# frozen_string_literal: true

require "test_helper"

class GemspecTest < Minitest::Test
  def test_requires_a_psych_version_with_safe_load_stream
    gemspec = Gem::Specification.load(File.expand_path("../yamlfmt.gemspec", __dir__))
    requirement = gemspec.runtime_dependencies.find { |dependency| dependency.name == "psych" }.requirement

    refute requirement.satisfied_by?(Gem::Version.new("5.2.4"))
    assert requirement.satisfied_by?(Gem::Version.new("5.2.5"))
  end
end
