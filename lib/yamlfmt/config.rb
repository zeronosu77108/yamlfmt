# frozen_string_literal: true

require "psych"

module Yamlfmt
  class Config
    FILE_NAME = ".yamlfmt.yml"
    TOP_LEVEL_KEYS = %w[rules exclude].freeze

    attr_reader :exclude, :warnings, :path

    def self.load(cwd: Dir.pwd)
      path = File.join(File.expand_path(cwd), FILE_NAME)
      return new({}, path:) unless File.file?(path)

      source = File.binread(path).force_encoding(Encoding::UTF_8)
      raise ConfigError, "#{path}: configuration must be valid UTF-8" unless source.valid_encoding?

      data = Psych.safe_load(source, filename: path, aliases: false) || {}
      new(data, path:)
    rescue Psych::Exception, SystemCallError => error
      raise ConfigError, "#{path}: #{error.message}"
    end

    def initialize(data, path: File.join(Dir.pwd, FILE_NAME))
      raise ConfigError, "configuration root must be a mapping" unless data.is_a?(Hash)

      @path = path
      @warnings = []
      warn_unknown_top_level_keys(data)
      @rule_options = parse_rules(fetch(data, "rules", {})).freeze
      @exclude = parse_exclude(fetch(data, "exclude", [])).freeze
      @warnings.freeze
    end

    def options_for(rule_class)
      value = @rule_options.fetch(rule_class.rule_id, {})
      return nil if value == false

      value
    end

    private

    def parse_rules(rules)
      raise ConfigError, "rules must be a mapping" unless rules.is_a?(Hash)

      rules.each_with_object({}) do |(id, value), result|
        id = id.to_s
        unless Rule::Registry.ids.include?(id)
          @warnings << "unknown rule: #{id}"
          next
        end

        result[id] = parse_rule_value(Rule::Registry.fetch(id), value)
      end
    end

    def parse_rule_value(rule_class, value)
      return false if value == false
      return {} if value == true
      raise ConfigError, "#{rule_class.rule_id} must be true, false, or a mapping" unless value.is_a?(Hash)

      defaults = rule_class.default_config
      value.each_with_object({}) do |(key, option_value), options|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise ConfigError, "option names for #{rule_class.rule_id} must be strings or symbols"
        end

        key = key.to_sym
        unless defaults.key?(key)
          @warnings << "unknown option for #{rule_class.rule_id}: #{key}"
          next
        end

        options[key] = option_value
      end
    end

    def parse_exclude(exclude)
      raise ConfigError, "exclude must be a list" unless exclude.is_a?(Array)

      exclude.map do |pattern|
        raise ConfigError, "exclude entries must be non-empty strings" unless pattern.is_a?(String) && !pattern.empty?
        raise ConfigError, "exclude entries must be relative paths" if pattern.start_with?("/")
        raise ConfigError, "exclude negation is not supported" if pattern.start_with?("!")

        normalized = pattern.delete_prefix("./").delete_suffix("/")
        components = normalized.split("/")
        if normalized.empty? || components.include?("..")
          raise ConfigError, "exclude entries must stay within the current directory"
        end

        normalized
      end
    end

    def warn_unknown_top_level_keys(data)
      data.each_key do |key|
        @warnings << "unknown configuration key: #{key}" unless TOP_LEVEL_KEYS.include?(key.to_s)
      end
    end

    def fetch(hash, key, default)
      return hash[key] if hash.key?(key)
      return hash[key.to_sym] if hash.key?(key.to_sym)

      default
    end
  end
end
