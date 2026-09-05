# frozen_string_literal: true

require "date"
require "psych/pure"

module Yamlfmt
  class Document
    Line = Data.define(:text, :content, :ending, :number, :start_offset)

    STANDARD_TAG_PREFIX = "tag:yaml.org,2002:"
    BLOCK_SCALAR_STYLES = [Psych::Nodes::Scalar::LITERAL, Psych::Nodes::Scalar::FOLDED].freeze

    attr_reader :source, :path, :ast, :lines

    def initialize(source, path: "<unknown>")
      @source = source.dup.freeze
      @path = path.to_s
      validate_encoding!
      @lines = build_lines.freeze
      @standard_stream = parse_standard
      validate_supported!
      @standard_document = @standard_stream.children.first
      @ast = parse_pure
      @node_ranges = build_node_ranges.freeze
    end

    def each_line(&block)
      return enum_for(__method__) unless block

      lines.each(&block)
    end

    def each_node(root = ast, &block)
      return enum_for(__method__, root) unless block
      return if root.nil? || root == false

      yield root
      root.children&.each { |child| each_node(child, &block) }
    end

    def range_for(node)
      @node_ranges[node.object_id]
    end

    def block_scalar?
      standard_nodes.any? do |node|
        node.is_a?(Psych::Nodes::Scalar) && BLOCK_SCALAR_STYLES.include?(node.style)
      end
    end

    def empty_yaml?
      @standard_document.nil?
    end

    def comment_values
      return comment_only_values if empty_yaml?

      seen = {}
      values = each_node.flat_map do |node|
        next [] unless node.respond_to?(:comments?) && node.comments?

        (node.comments.leading + node.comments.trailing).filter_map do |comment|
          next if seen[comment.object_id]

          seen[comment.object_id] = true
          normalize_comment(comment.value)
        end
      end

      values.sort
    end

    def preferred_line_ending
      endings = lines.filter_map { |line| line.ending unless line.ending.empty? }
      return "\n" if endings.empty?

      endings.tally.max_by { |ending, count| [count, -endings.index(ending)] }.first
    end

    def line_and_column(byte_offset)
      raise ArgumentError, "offset is outside the source" unless byte_offset.between?(0, source.bytesize)

      line = lines.reverse_each.find { |candidate| candidate.start_offset <= byte_offset }
      return [1, 1] unless line

      prefix = source.byteslice(line.start_offset, byte_offset - line.start_offset)
      [line.number, prefix.length + 1]
    end

    private

    def validate_encoding!
      if source.start_with?("\uFEFF")
        raise UnsupportedFileError, "byte order marks are not supported"
      end

      return if source.encoding == Encoding::UTF_8 && source.valid_encoding?

      raise UnsupportedFileError, "only valid UTF-8 input is supported"
    end

    def parse_standard
      Psych.parse_stream(source, filename: path)
    rescue Psych::SyntaxError => error
      raise ParseError, error.message
    end

    def parse_pure
      return nil if empty_yaml?

      Psych::Pure.parse(source, filename: path, comments: true)
    rescue Psych::SyntaxError => error
      raise ParseError, error.message
    rescue NoMethodError => error
      raise UnsupportedFileError, "psych-pure could not parse this document: #{error.message}"
    end

    def validate_supported!
      if @standard_stream.children.length > 1
        raise UnsupportedFileError, "multiple YAML documents are not supported"
      end

      standard_nodes.each do |node|
        if custom_tag?(node)
          raise UnsupportedFileError, "custom YAML tags are not supported"
        end

        if node.is_a?(Psych::Nodes::Scalar) && node.anchor
          raise UnsupportedFileError, "anchors on scalar values are not supported"
        end
      end
    end

    def custom_tag?(node)
      return false unless node.respond_to?(:tag)

      tag = node.tag
      tag && tag != "!" && !tag.start_with?(STANDARD_TAG_PREFIX)
    end

    def standard_nodes
      return [] unless @standard_stream

      @standard_nodes ||= walk(@standard_stream).freeze
    end

    def walk(node, result = [])
      result << node
      node.children&.each { |child| walk(child, result) }
      result
    end

    def build_node_ranges
      return {} unless ast

      pure_scalars = each_node.select { |node| node.is_a?(Psych::Nodes::Scalar) }
      psych_scalars = standard_nodes.select { |node| node.is_a?(Psych::Nodes::Scalar) }
      return {} unless pure_scalars.length == psych_scalars.length

      pure_scalars.zip(psych_scalars).each_with_object({}) do |(pure_node, psych_node), ranges|
        next unless pure_node.value == psych_node.value && pure_node.style == psych_node.style

        range = range_from_location(psych_node)
        next unless range
        next unless source.byteslice(range.start_offset, range.length) == pure_node.source

        ranges[pure_node.object_id] = range
      end
    end

    def range_from_location(node)
      start_offset = byte_offset(node.start_line, node.start_column)
      end_offset = byte_offset(node.end_line, node.end_column)
      SourceRange.new(start_offset:, end_offset:)
    rescue ArgumentError, IndexError
      nil
    end

    def byte_offset(line_index, character_column)
      line = lines.fetch(line_index)
      prefix = line.text[0, character_column]
      raise ArgumentError, "column is outside the line" unless prefix

      line.start_offset + prefix.bytesize
    end

    def build_lines
      result = []
      start_offset = 0
      index = 0

      while index < source.bytesize
        byte = source.getbyte(index)
        if byte == 13 || byte == 10
          ending_length = (byte == 13 && source.getbyte(index + 1) == 10) ? 2 : 1
          result << build_line(start_offset, index, ending_length, result.length + 1)
          index += ending_length
          start_offset = index
        else
          index += 1
        end
      end

      result << build_line(start_offset, source.bytesize, 0, result.length + 1) if start_offset < source.bytesize
      result
    end

    def build_line(start_offset, content_end, ending_length, number)
      content = source.byteslice(start_offset, content_end - start_offset)
      ending = source.byteslice(content_end, ending_length)
      Line.new(
        text: "#{content}#{ending}",
        content:,
        ending:,
        number:,
        start_offset:
      )
    end

    def comment_only_values
      lines.filter_map do |line|
        content = line.content.lstrip
        normalize_comment(content) if content.start_with?("#")
      end.sort
    end

    def normalize_comment(value)
      value.sub(/[ \t]+\z/, "")
    end
  end
end
