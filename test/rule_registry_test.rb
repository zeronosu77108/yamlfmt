# frozen_string_literal: true

require "test_helper"

class RuleRegistryTest < Minitest::Test
  def setup
    @original_rules = Yamlfmt::Rule::Registry.rules
    Yamlfmt::Rule::Registry.clear
  end

  def teardown
    Yamlfmt::Rule::Registry.clear
    @original_rules.each { |rule| Yamlfmt::Rule::Registry.register(rule) }
  end

  def test_orders_rules_by_priority_then_id
    later = build_rule("later", 200)
    beta = build_rule("beta", 100)
    alpha = build_rule("alpha", 100)

    [later, beta, alpha].each { |rule| Yamlfmt::Rule::Registry.register(rule) }

    assert_equal %w[alpha beta later], Yamlfmt::Rule::Registry.rules.map(&:rule_id)
  end

  def test_rejects_duplicate_ids
    Yamlfmt::Rule::Registry.register(build_rule("duplicate", 100))

    assert_raises(ArgumentError) do
      Yamlfmt::Rule::Registry.register(build_rule("duplicate", 200))
    end
  end

  private

  def build_rule(id, priority)
    Class.new(Yamlfmt::Rule::Base) do
      rule_id id
      priority priority
    end
  end
end
