# frozen_string_literal: true

require "test_helper"

class SafetyValidatorTest < Minitest::Test
  def test_accepts_equivalent_values_including_safe_core_classes
    source = <<~YAML
      date: 2025-12-01
      time: 2025-12-01 12:30:00 Z
      symbol: :value
    YAML
    document = Yamlfmt::Document.new(source)

    assert_instance_of Yamlfmt::Document, Yamlfmt::SafetyValidator.new.call(document, source)
  end

  def test_accepts_removing_trailing_whitespace_from_a_comment
    original = Yamlfmt::Document.new("key: value # comment  \n")

    Yamlfmt::SafetyValidator.new.call(original, "key: value # comment\n")
  end

  def test_rejects_a_changed_value
    original = Yamlfmt::Document.new("key: value\n")

    assert_raises(Yamlfmt::ValidationError) do
      Yamlfmt::SafetyValidator.new.call(original, "key: changed\n")
    end
  end

  def test_rejects_a_removed_comment
    original = Yamlfmt::Document.new("key: value # comment\n")

    assert_raises(Yamlfmt::ValidationError) do
      Yamlfmt::SafetyValidator.new.call(original, "key: value\n")
    end
  end

  def test_compares_nan_values
    original = Yamlfmt::Document.new("value: .nan\n")

    Yamlfmt::SafetyValidator.new.call(original, "value: .NaN\n")
  end
end
