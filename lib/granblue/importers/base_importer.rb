# frozen_string_literal: true

module Granblue
  module Importers
    class BaseImporter
      attr_reader :new_records

      def initialize(file_path, test_mode: false, verbose: false, logger: nil)
        @file_path = file_path
        @test_mode = test_mode
        @verbose = verbose
        @logger = logger
        @new_records = Hash.new { |h, k| h[k] = [] }
      end

      def import
        CSV.foreach(@file_path, headers: true) do |row|
          import_row(row)
        end
        @new_records
      end

      private

      def import_row(row)
        attributes = build_attributes(row)
        record = create_record(attributes)
        track_new_record(record) if record
      end

      def create_record(attributes)
        if @test_mode
          log_test_creation(attributes)
          nil
        else
          model_class.create!(attributes)
        end
      end

      def track_new_record(record)
        type = model_class.name.demodulize.downcase
        @new_records[type] << record.granblue_id
        log_new_record(record) if @verbose
      end

      def log_test_creation(attributes)
        @logger&.send(:log_operation, "Create #{model_class.name}: #{attributes.inspect}")
      end

      def log_new_record(record)
        puts "Created #{model_class.name} with ID: #{record.granblue_id}"
      end

      def parse_value(value)
        return nil if value.nil? || value.strip.empty?
        value
      end

      def parse_integer(value)
        return nil if value.nil? || value.strip.empty?
        value.to_i
      end

      def parse_float(value)
        return nil if value.nil? || value.strip.empty?
        value.to_f
      end

      def parse_boolean(value)
        return nil if value.nil? || value.strip.empty?
        value == 'true'
      end

      def parse_date(date_str)
        return nil if date_str.nil? || date_str.strip.empty?
        Date.parse(date_str) rescue nil
      end

      def parse_array(array_str)
        return [] if array_str.nil? || array_str.strip.empty?
        array_str.tr('{}', '').split(',')
      end

      def parse_integer_array(array_str)
        parse_array(array_str).map(&:to_i)
      end

      def model_class
        raise NotImplementedError, 'Subclasses must define model_class'
      end

      def build_attributes(row)
        raise NotImplementedError, 'Subclasses must define build_attributes'
      end
    end
  end
end
