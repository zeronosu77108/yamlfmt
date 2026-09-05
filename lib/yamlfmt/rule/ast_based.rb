# frozen_string_literal: true

module Yamlfmt
  module Rule
    class AstBased < Base
      def call(document)
        document.each_node.flat_map do |node|
          Array(check_node(node, document))
        end
      end

      def check_node(_node, _document)
        raise NotImplementedError
      end
    end
  end
end
