module Granblue
  module Transformers
    class TransformerError < StandardError
      attr_reader :details

      def initialize(message, details = nil)
        @details = details
        super(message)
      end
    end
  end
end
