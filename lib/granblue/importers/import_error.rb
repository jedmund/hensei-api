module Granblue
  module Importers
    class ImportError < StandardError
      attr_reader :file_name, :details

      def initialize(file_name:, details:)
        @file_name = file_name
        @details = details
        super(build_message)
      end

      private

      def build_message
        "Error importing #{file_name}: #{details}"
      end
    end

    def format_attributes(attributes)
      attributes.map do |key, value|
        formatted_value = case value
                          when Array
                            value.empty? ? '[]' : value.inspect
                          else
                            value.inspect
                          end
        "  #{key}: #{formatted_value}"
      end.join("\n")
    end
  end
end
