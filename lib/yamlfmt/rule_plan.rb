# frozen_string_literal: true

module Yamlfmt
  class RulePlan
    def call(config)
      Rule::Registry.rules.filter_map do |rule_class|
        options = config.options_for(rule_class)
        rule_class.new(options) if options
      end
    end
  end
end
