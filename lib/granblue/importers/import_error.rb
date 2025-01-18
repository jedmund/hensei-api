module Granblue
  module Importers
    # Custom error class for handling import-related exceptions
    #
    # @example Raising an import error
    #   raise ImportError.new(
    #     file_name: 'characters.csv',
    #     details: 'Missing required column: name_en'
    #   )
    #
    # @note This error provides detailed information about import failures
    class ImportError < StandardError
      # @return [String] The name of the file that caused the import error
      attr_reader :file_name

      # @return [String] Detailed information about the error
      attr_reader :details

      # Create a new ImportError instance
      #
      # @param file_name [String] The name of the file that caused the import error
      # @param details [String] Detailed information about the error
      # @example
      #   ImportError.new(
      #     file_name: 'weapons.csv',
      #     details: 'Invalid data in rarity column'
      #   )
      def initialize(file_name:, details:)
        @file_name = file_name
        @details = details
        super(build_message)
      end

      private

      # Constructs a comprehensive error message
      #
      # @return [String] Formatted error message combining file name and details
      # @example
      #   # Returns "Error importing weapons.csv: Invalid data in rarity column"
      #   build_message
      def build_message
        "Error importing #{file_name}: #{details}"
      end
    end

    # Formats attributes into a human-readable string representation
    #
    # @param attributes [Hash] A hash of attributes to format
    # @return [String] A formatted string with each attribute on a new line
    # @example
    #   attributes = {
    #     name: 'Example Weapon',
    #     rarity: 5,
    #     elements: ['fire', 'water']
    #   }
    #   format_attributes(attributes)
    #   # Returns:
    #   #   name: "Example Weapon"
    #   #   rarity: 5
    #   #   elements: ["fire", "water"]
    # @note Handles various attribute types including arrays and nil values
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
