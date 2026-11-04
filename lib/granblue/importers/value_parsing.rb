# frozen_string_literal: true

module Granblue
  module Importers
    # Parses CSV cell values for the catalogue importers. A blank cell is nil
    # (an empty list for arrays).
    module ValueParsing
      private

      # Parses each attribute from the CSV column of the same name.
      # @param row [CSV::Row] Row to parse
      # @param columns [Hash{Symbol => Symbol}] attribute => type (:value, :integer, ...)
      # @return [Hash] Parsed attributes, in the order of columns
      def parse_columns(row, columns)
        columns.to_h { |column, type| [column, send(:"parse_#{type}", row[column.to_s])] }
      end

      # Parse a string value, returning nil if empty
      # @param value [String, nil] Value to parse
      # @return [String, nil] Parsed value
      def parse_value(value)
        return nil if value.nil? || value.strip.empty?

        value
      end

      # Parse an integer value
      # @param value [String, nil] Value to parse
      # @return [Integer, nil] Parsed value
      def parse_integer(value)
        return nil if value.nil? || value.strip.empty?

        value.to_i
      end

      # Parse a float value
      # @param value [String, nil] Value to parse
      # @return [Float, nil] Parsed value
      def parse_float(value)
        return nil if value.nil? || value.strip.empty?

        value.to_f
      end

      # Parse a boolean value
      # @param value [String, nil] Value to parse
      # @return [Boolean, nil] Parsed value
      def parse_boolean(value)
        return nil if value.nil? || value.strip.empty?

        value == 'true'
      end

      # Parse a date string
      # @param date_str [String, nil] Date string to parse
      # @return [Date, nil] Parsed date
      def parse_date(date_str)
        return nil if date_str.nil? || date_str.strip.empty?

        begin
          Date.parse(date_str)
        rescue StandardError
          nil
        end
      end

      # Parse a string array
      # @param array_str [String, nil] Array string to parse
      # @return [Array<String>] Parsed array
      def parse_array(array_str)
        return [] if array_str.nil? || array_str.strip.empty?

        array_str.tr('{}', '').split(',')
      end

      # Parse an integer array
      # @param array_str [String, nil] Array string to parse
      # @return [Array<Integer>] Parsed array
      def parse_integer_array(array_str)
        parse_array(array_str).map(&:to_i)
      end
    end
  end
end
