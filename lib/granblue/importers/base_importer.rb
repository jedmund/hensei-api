# frozen_string_literal: true

require_relative 'import_error'

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

          # Check if record exists before doing any validation
          existing_record = model_class.find_by(granblue_id: attributes[:granblue_id])

          if existing_record
            simulate_update(existing_record, attributes, simulated_updated, type)
          else
            validate_required_attributes(attributes)
            simulate_create(attributes, simulated_new, type)
          end
        end

        { new: simulated_new, updated: simulated_updated }
      rescue StandardError => e
        handle_error(e)
      end

      private

      def import_row(row)
        attributes = build_attributes(row)
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
            [model_class.create!(attributes), false]
          end
        end
      end

      def simulate_create(attributes, simulated_new, type)
        test_record = model_class.new(attributes)
        validate_record(test_record)

        log_test_creation(attributes)
        simulated_new[type] << {
          granblue_id: attributes[:granblue_id],
          name_en: attributes[:name_en],
          attributes: attributes,
          operation: :create
        }
      end

      def simulate_update(existing_record, attributes, simulated_updated, type)
        update_attributes = attributes.compact
        would_update = update_attributes.any? { |key, value| existing_record[key] != value }

        if would_update
          # Create a test record with existing data
          test_record = existing_record.dup

          # Validate only the columns being updated
          validate_update_attributes(update_attributes)

          # Apply the updates and validate the resulting record
          test_record.assign_attributes(update_attributes)
          validate_record(test_record)

          log_test_update(existing_record, attributes)
          simulated_updated[type] << {
            granblue_id: attributes[:granblue_id],
            name_en: attributes[:name_en] || existing_record.name_en,
            attributes: update_attributes,
            operation: :update
          }
        end
      end

      def validate_required_attributes(attributes)
        required_columns = model_class.columns.select { |c| !c.null }.map(&:name)

        missing_columns = required_columns.select do |column|
          attributes[column.to_sym].nil? &&
            !model_class.column_defaults[column] &&
            !%w[id created_at updated_at].include?(column)
        end

        if missing_columns.any?
          details = [
            "Missing required columns:",
            missing_columns.map { |col| "  • #{col}" },
            "",
            "Affected model: #{model_class.name}"
          ].flatten.join("\n")

          raise ImportError.new(
            file_name: File.basename(@file_path),
            details: details
          )
        end
      end

      def validate_update_attributes(update_attributes)
        # Get the list of columns that cannot be null in the database
        required_columns = model_class.columns.select { |c| !c.null }.map(&:name)

        # For updates, we only need to validate the attributes that are being updated
        update_columns = update_attributes.keys.map(&:to_s)

        # Only check required columns that are included in the update
        missing_columns = required_columns.select do |column|
          update_columns.include?(column) &&
            update_attributes[column.to_sym].nil? &&
            !model_class.column_defaults[column] &&
            !%w[id created_at updated_at].include?(column)
        end

        if missing_columns.any?
          details = [
            "Missing required values for update:",
            missing_columns.map { |col| "  • #{col}" },
            "",
            "Affected model: #{model_class.name}"
          ].flatten.join("\n")

          raise ImportError.new(
            file_name: File.basename(@file_path),
            details: details
          )
        end
      end

      def validate_record(record)
        unless record.valid?
          raise ImportError.new(
            file_name: File.basename(@file_path),
            details: format_validation_error(ActiveRecord::RecordInvalid.new(record))
          )
        end

        begin
          ActiveRecord::Base.transaction(requires_new: true) do
            record.save!
            raise ActiveRecord::Rollback
          end
        rescue ActiveRecord::StatementInvalid => e
          if e.message.include?('violates not-null constraint')
            column = e.message.match(/column "([^"]+)"/)[1]
            details = [
              "Database constraint violation:",
              "  • Column '#{column}' cannot be null",
              "",
              "Affected model: #{model_class.name}"
            ].join("\n")

            raise ImportError.new(
              file_name: File.basename(@file_path),
              details: details
            )
          end
          raise ImportError.new(
            file_name: File.basename(@file_path),
            details: format_standard_error(e)
          )
        end
      end

      def track_record(result)
        record, was_updated = result
        type = model_class.name.demodulize.downcase

        record_info = {
          granblue_id: record.granblue_id,
          name_en: record.name_en
        }

        if was_updated
          @updated_records[type] << record_info
          log_updated_record(record) if @verbose
        else
          @new_records[type] << record_info
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
        update_attributes = attributes.compact
        @logger&.log_step("\nUpdate #{model_class.name} #{record.granblue_id}:")
        @logger&.log_verbose("Current values:")
        @logger&.log_verbose(format_attributes(record.attributes.symbolize_keys))
        @logger&.log_verbose("\nNew values:")
        @logger&.log_verbose(format_attributes(update_attributes))
        @logger&.log_step("\n")
      end

      def log_test_creation(attributes)
        @logger&.log_step("\nCreate #{model_class.name}:")
        @logger&.log_verbose(format_attributes(attributes))
        @logger&.log_step("\n")
      end

      def log_new_record(record)
        @logger&.log_verbose("Created #{model_class.name} with ID: #{record.granblue_id}\n")
      end

      def log_updated_record(record)
        @logger&.log_verbose("Updated #{model_class.name} with ID: #{record.granblue_id}\n")
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

      def handle_error(error)
        details = case error
                  when ActiveRecord::RecordInvalid
                    format_validation_error(error)
                  else
                    format_standard_error(error)
                  end

        raise ImportError.new(
          file_name: File.basename(@file_path),
          details: details
        )
      end

      def format_validation_error(error)
        [
          "Validation failed:",
          error.record.errors.full_messages.map { |msg| "  • #{msg}" },
          "",
          "Record attributes:",
          format_attributes(error.record.attributes.symbolize_keys)
        ].flatten.join("\n")
      end

      def format_standard_error(error)
        if @verbose && error.respond_to?(:backtrace)
          [
            error.message,
            "",
            "Backtrace:",
            error.backtrace.take(3).map { |line| "  #{line}" }
          ].flatten.join("\n")
        else
          error.message.to_s
        end
      end
    end
  end
end
