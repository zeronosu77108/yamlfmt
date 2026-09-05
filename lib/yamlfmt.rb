# frozen_string_literal: true

require_relative "yamlfmt/version"
require_relative "yamlfmt/errors"
require_relative "yamlfmt/source_range"
require_relative "yamlfmt/edit"
require_relative "yamlfmt/finding"
require_relative "yamlfmt/document"
require_relative "yamlfmt/corrector"
require_relative "yamlfmt/safety_validator"
require_relative "yamlfmt/processor"
require_relative "yamlfmt/rule/base"
require_relative "yamlfmt/rule/registry"
require_relative "yamlfmt/rule/line_based"
require_relative "yamlfmt/rule/ast_based"
require_relative "yamlfmt/rule/trailing_whitespace"
require_relative "yamlfmt/rule/blank_lines"
require_relative "yamlfmt/rule/final_newline"
require_relative "yamlfmt/rule/unnecessary_quotes"

module Yamlfmt
end
