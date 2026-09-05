# frozen_string_literal: true

module Yamlfmt
  module Rule
    module Registry
      class << self
        def register(rule_class)
          id = rule_class.rule_id
          raise ArgumentError, "rule must define an id" if id.nil? || id.empty?
          raise ArgumentError, "rule #{id.inspect} is already registered" if rules_by_id.key?(id)

          rules_by_id[id] = rule_class
        end

        def fetch(id)
          rules_by_id.fetch(id)
        end

        def rules
          rules_by_id.values.sort_by { |rule| [rule.priority, rule.rule_id] }
        end

        def ids
          rules_by_id.keys.freeze
        end

        def clear
          @rules_by_id = {}
        end

        private

        def rules_by_id
          @rules_by_id ||= {}
        end
      end
    end
  end
end
