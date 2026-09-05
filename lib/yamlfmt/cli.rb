# frozen_string_literal: true

require "optparse"
require "pathname"

module Yamlfmt
  class CLI
    INIT_CONFIG = <<~YAML
      # .yamlfmt.yml
      rules:
        trailing-whitespace: true
        final-newline: true
        blank-lines:
          max: 1
        unnecessary-quotes: true

      exclude:
        - vendor
        - node_modules
    YAML

    def self.start(argv, stdout: $stdout, stderr: $stderr, cwd: Dir.pwd)
      new(stdout:, stderr:, cwd:).run(argv)
    end

    def initialize(stdout:, stderr:, cwd:, processor: Processor.new, diff: UnifiedDiff.new)
      @stdout = stdout
      @stderr = stderr
      @cwd = File.expand_path(cwd)
      @processor = processor
      @diff = diff
    end

    def run(argv)
      options, paths, parser = parse(argv)
      return print_help(parser) if options[:help]
      return print_version if options[:version]
      return initialize_config(options, paths) if options[:init]

      validate_modes!(options)
      process_files(options, paths)
    rescue OptionParser::ParseError, ConfigError, PathError => error
      @stderr.puts("yamlfmt: #{error.message}")
      1
    end

    private

    def parse(argv)
      options = {fix: false, diff: false, init: false, color: true}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: yamlfmt [options] [paths...]"
        opts.on("--fix", "Rewrite files in place") { options[:fix] = true }
        opts.on("--diff", "Print a unified diff without rewriting files") { options[:diff] = true }
        opts.on("--init", "Create .yamlfmt.yml in the current directory") { options[:init] = true }
        opts.on("--no-color", "Disable colored output") { options[:color] = false }
        opts.on("--version", "Print the version") { options[:version] = true }
        opts.on("-h", "--help", "Print this help") { options[:help] = true }
      end
      paths = parser.permute!(argv.dup)
      [options, paths, parser]
    end

    def validate_modes!(options)
      raise OptionParser::InvalidOption, "--fix and --diff cannot be used together" if options[:fix] && options[:diff]
    end

    def initialize_config(options, paths)
      if options[:fix] || options[:diff] || !paths.empty?
        raise OptionParser::InvalidOption, "--init cannot be combined with formatting options or paths"
      end

      path = File.join(@cwd, Config::FILE_NAME)
      raise ConfigError, "#{Config::FILE_NAME} already exists" if File.exist?(path)

      File.write(path, INIT_CONFIG)
      @stdout.puts("Created #{Config::FILE_NAME}")
      0
    end

    def process_files(options, paths)
      config = Config.load(cwd: @cwd)
      config.warnings.each { |warning| warn_message(warning) }
      rules = RulePlan.new.call(config)
      files = FileFinder.new(cwd: @cwd, exclude: config.exclude).call(paths)
      state = {error: false, finding: false, uncorrected: false}

      files.each do |path|
        process_file(path, rules, options, state)
      end

      return 1 if state[:error] || state[:uncorrected]
      return 0 if options[:fix]

      state[:finding] ? 1 : 0
    end

    def process_file(path, rules, options, state)
      source = File.binread(path).force_encoding(Encoding::UTF_8)
      result = @processor.call(source, path:, rules:)
      display_path = display_path(path)
      result.warnings.each { |warning| warn_message("#{display_path}: #{warning}") }
      state[:finding] ||= !result.findings.empty?

      if options[:diff]
        print_diff(result, display_path, options)
        print_findings(result, display_path, findings: result.findings.reject(&:autocorrectable?))
      else
        print_findings(result, display_path)
      end

      if options[:fix]
        File.binwrite(path, result.formatted_source) if result.changed?
        state[:uncorrected] ||= result.findings.any? { |finding| !finding.autocorrectable? }
      end
    rescue Error, SystemCallError => error
      @stderr.puts("#{display_path(path)}: #{error.message}")
      state[:error] = true
    end

    def print_findings(result, display_path, findings: result.findings)
      findings.each do |finding|
        line, column = result.document.line_and_column(finding.range.start_offset)
        @stdout.puts("#{display_path}:#{line}:#{column}: #{finding.rule_id} #{finding.message}")
      end
    end

    def print_diff(result, display_path, options)
      return unless result.changed?

      output = @diff.call(result.source, result.formatted_source, path: display_path)
      @stdout.write(colorize_diff(output, options))
    end

    def colorize_diff(output, options)
      return output unless options[:color] && @stdout.respond_to?(:tty?) && @stdout.tty?

      output.lines.map do |line|
        case line
        when /\A\+(?!\+\+)/ then "\e[32m#{line}\e[0m"
        when /\A-(?!--)/ then "\e[31m#{line}\e[0m"
        when /\A@@/ then "\e[36m#{line}\e[0m"
        else line
        end
      end.join
    end

    def display_path(path)
      relative = Pathname(File.expand_path(path)).relative_path_from(Pathname(@cwd)).to_s
      return File.expand_path(path) if relative == ".." || relative.start_with?("../")

      relative
    rescue ArgumentError
      File.expand_path(path)
    end

    def warn_message(message)
      @stderr.puts("warning: #{message}")
    end

    def print_help(parser)
      @stdout.puts(parser)
      0
    end

    def print_version
      @stdout.puts(Yamlfmt::VERSION)
      0
    end
  end
end
