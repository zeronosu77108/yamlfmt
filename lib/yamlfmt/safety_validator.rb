# frozen_string_literal: true

module Yamlfmt
  class SafetyValidator
    PERMITTED_CLASSES = [Date, Time, Symbol].freeze

    def call(original_document, candidate_source)
      candidate = Document.new(candidate_source, path: original_document.path)
      validate_values!(original_document, candidate)
      validate_comments!(original_document, candidate)
      candidate
    rescue ParseError, UnsupportedFileError => error
      raise ValidationError, "formatted source could not be parsed safely: #{error.message}"
    end

    private

    def validate_values!(original, candidate)
      original_values = load_values(original)
      candidate_values = load_values(candidate)
      return if equivalent?(original_values, candidate_values)

      raise ValidationError, "formatting changed the YAML value"
    rescue Psych::Exception => error
      raise ValidationError, "YAML value could not be loaded safely: #{error.message}"
    end

    def validate_comments!(original, candidate)
      return if original.comment_values == candidate.comment_values

      raise ValidationError, "formatting changed YAML comments"
    end

    def load_values(document)
      Psych.safe_load_stream(
        document.source,
        filename: document.path,
        permitted_classes: PERMITTED_CLASSES,
        aliases: true
      )
    end

    def equivalent?(left, right, seen = {})
      return true if left.equal?(right)
      return false unless left.instance_of?(right.class)

      pair = [left.object_id, right.object_id]
      return true if seen[pair]

      seen[pair] = true

      case left
      when Array
        left.length == right.length && left.zip(right).all? { |left_item, right_item| equivalent?(left_item, right_item, seen) }
      when Hash
        equivalent_hash?(left, right, seen)
      when Float
        (left.nan? && right.nan?) || left == right
      else
        left == right
      end
    end

    def equivalent_hash?(left, right, seen)
      return false unless left.length == right.length

      left.to_a.zip(right.to_a).all? do |(left_key, left_value), (right_key, right_value)|
        equivalent?(left_key, right_key, seen) && equivalent?(left_value, right_value, seen)
      end
    end
  end
end
