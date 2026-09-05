# frozen_string_literal: true

module Yamlfmt
  module Rule
    class Base
      UNSET = Object.new.freeze

      class << self
        def rule_id(value = UNSET)
          return @rule_id if value.equal?(UNSET)

          @rule_id = value.to_s.freeze
        end

        def default_config(value = UNSET)
          return @default_config || {} if value.equal?(UNSET)

          @default_config = value.freeze
        end

        def priority(value = UNSET)
          return @priority || 100 if value.equal?(UNSET)

          @priority = Integer(value)
        end

        def autocorrectable?
          true
        end
      end

      attr_reader :config

      def initialize(config = {})
        @config = self.class.default_config.merge(config).freeze
      end

      def call(_document)
        raise NotImplementedError
      end
    end
  end
end
