# frozen_string_literal: true

require "test_helper"

class ProcessorTest < Minitest::Test
  def test_applies_all_rules_and_validates_the_result
    source = "# comment  \nname: \"value\"\n  \n \nnext: \"yes\""
    result = Yamlfmt::Processor.new.call(source, path: "example.yml")

    assert_equal "# comment\nname: value\n\nnext: \"yes\"\n", result.formatted_source
    assert result.changed?

    second_result = Yamlfmt::Processor.new.call(result.formatted_source, path: "example.yml")
    refute second_result.changed?
  end

  def test_warns_when_line_rules_are_skipped
    source = "name: \"value\"  \nbody: |\n  text  \n"
    result = Yamlfmt::Processor.new.call(source, path: "example.yml")

    assert_equal "name: value  \nbody: |\n  text  \n", result.formatted_source
    assert_equal ["line-based rules were skipped because the file contains a block scalar"], result.warnings
  end
end
