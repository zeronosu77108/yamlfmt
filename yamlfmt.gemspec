# frozen_string_literal: true

require_relative "lib/yamlfmt/version"

Gem::Specification.new do |spec|
  spec.name = "yamlfmt"
  spec.version = Yamlfmt::VERSION
  spec.authors = ["zeronosu77108"]
  spec.email = ["mail@zeronosu77108.com"]

  spec.summary = "A comment-preserving, minimal-diff YAML formatter for Ruby"
  spec.description = "Applies targeted edits while preserving comments and untouched formatting."
  spec.homepage = "https://github.com/zeronosu77108/yamlfmt"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "psych", ">= 5.2.5", "< 6"
  spec.add_dependency "psych-pure", "~> 0.3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
