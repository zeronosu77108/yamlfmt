# frozen_string_literal: true

require "test_helper"

class DocumentTest < Minitest::Test
  def test_maps_psych_pure_scalars_to_exact_byte_ranges
    source = <<~YAML
      日本語:
        key: "value" # comment
      flow: ['same', 'same']
    YAML
    document = Yamlfmt::Document.new(source, path: "example.yml")
    quoted = document.each_node.select do |node|
      node.is_a?(Psych::Nodes::Scalar) && ["\"value\"", "'same'"].include?(node.source)
    end

    assert_equal ["\"value\"", "'same'", "'same'"], quoted.map(&:source)
    assert_equal quoted.map(&:source), quoted.map { |node| source.byteslice(document.range_for(node).start_offset, document.range_for(node).length) }
  end

  def test_collects_logical_comment_content
    source = "key: value # comment   \n# leading\nnext: value\n"
    document = Yamlfmt::Document.new(source)

    assert_equal ["# comment", "# leading"], document.comment_values
  end

  def test_collects_comments_from_a_comment_only_file
    document = Yamlfmt::Document.new("# second   \n  # first\n")

    assert document.empty_yaml?
    assert_equal ["# first", "# second"], document.comment_values
  end

  def test_detects_block_scalars
    document = Yamlfmt::Document.new("key: |\n  text\n")

    assert document.block_scalar?
  end

  def test_rejects_multiple_documents
    error = assert_raises(Yamlfmt::UnsupportedFileError) do
      Yamlfmt::Document.new("---\none: 1\n---\ntwo: 2\n")
    end

    assert_match(/multiple YAML documents/, error.message)
  end

  def test_rejects_custom_tags
    assert_raises(Yamlfmt::UnsupportedFileError) do
      Yamlfmt::Document.new("value: !custom thing\n")
    end
  end

  def test_rejects_scalar_anchors
    assert_raises(Yamlfmt::UnsupportedFileError) do
      Yamlfmt::Document.new("value: &anchor thing\nother: *anchor\n")
    end
  end

  def test_rejects_a_byte_order_mark
    assert_raises(Yamlfmt::UnsupportedFileError) do
      Yamlfmt::Document.new("\uFEFFkey: value\n")
    end
  end

  def test_wraps_syntax_errors
    assert_raises(Yamlfmt::ParseError) do
      Yamlfmt::Document.new("key: [\n")
    end
  end
end
