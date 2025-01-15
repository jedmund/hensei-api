# frozen_string_literal: true

module Granblue
  module Importers
    class BaseImporter
      attr_reader :new_records, :updated_records

      def initialize(file_path, test_mode: false, verbose: false, logger: nil)
        @file_path = file_path
        @test_mode = test_mode
        @verbose = verbose
        @logger = logger
        @new_records = Hash.new { |h, k| h[k] = [] }
        @updated_records = Hash.new { |h, k| h[k] = [] }
      end

      def import
        CSV.foreach(@file_path, headers: true) do |row|
          import_row(row)
        end
        { new: @new_records, updated: @updated_records }
      end

      def simulate_import
        simulated_new = Hash.new { |h, k| h[k] = [] }
        simulated_updated = Hash.new { |h, k| h[k] = [] }
        type = model_class.name.demodulize.downcase

        CSV.foreach(@file_path, headers: true) do |row|
          attributes = build_attributes(row)
          existing_record = model_class.find_by(granblue_id: attributes[:granblue_id])

          if existing_record
            # For updates, only include non-nil attributes
            update_attributes = attributes.compact
            would_update = update_attributes.any? { |key, value| existing_record[key] != value }

            if would_update
              log_test_update(existing_record, attributes)
              simulated_updated[type] << {
                granblue_id: attributes[:granblue_id],
                name_en: attributes[:name_en] || existing_record.name_en,
                attributes: update_attributes,
                operation: :update
              }
            end
          else
            log_test_creation(attributes)
            simulated_new[type] << {
              granblue_id: attributes[:granblue_id],
              name_en: attributes[:name_en],
              attributes: attributes,
              operation: :create
            }
          end
        end

        { new: simulated_new, updated: simulated_updated }
      end

      private

      def import_row(row)
        attributes = build_attributes(row)
        # Remove nil values from attributes hash for updates
        # Keep them for new records to ensure proper defaults
        record = find_or_create_record(attributes)
        track_record(record) if record
      end

      def find_or_create_record(attributes)
        existing_record = model_class.find_by(granblue_id: attributes[:granblue_id])

        if existing_record
          if @test_mode
            log_test_update(existing_record, attributes)
            nil
          else
            # For updates, only include non-nil attributes
            update_attributes = attributes.compact
            was_updated = update_attributes.any? { |key, value| existing_record[key] != value }
            existing_record.update!(update_attributes) if was_updated
            [existing_record, was_updated]
          end
        else
          if @test_mode
            log_test_creation(attributes)
            nil
          else
            # For new records, use all attributes including nil values
            [model_class.create!(attributes), false]
          end
        end
      end

      def track_record(result)
        record, was_updated = result
        type = model_class.name.demodulize.downcase

        if was_updated
          @updated_records[type] << record.granblue_id
          log_updated_record(record) if @verbose
        else
          @new_records[type] << record.granblue_id
          log_new_record(record) if @verbose
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
          "    #{key}: #{formatted_value}"
        end.join("\n")
      end

      def log_test_update(record, attributes)
        # For test mode, show only the attributes that would be updated
        update_attributes = attributes.compact
        @logger&.log_step("Updating #{model_class.name} #{record.granblue_id}...")
        @logger&.log_verbose(format_attributes(update_attributes))
        @logger&.log_step("\n\n") if @verbose
      end

      def log_test_creation(attributes)
        @logger&.log_step("Creating #{model_class.name}...")
        @logger&.log_verbose(format_attributes(attributes))
        @logger&.log_step("\n\n") if @verbose
      end

      def log_new_record(record)
        @logger&.log_verbose("Created #{model_class.name} with ID: #{record.granblue_id}")
      end

      def log_updated_record(record)
        @logger&.log_verbose("Updated #{model_class.name} with ID: #{record.granblue_id}")
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
