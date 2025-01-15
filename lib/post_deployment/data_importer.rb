# frozen_string_literal: true

require_relative '../logging_helper'

module PostDeployment
  class DataImporter
    include LoggingHelper

    def initialize(test_mode:, verbose:, test_transaction: nil, force: false)
      @test_mode = test_mode
      @verbose = verbose
      @test_transaction = test_transaction
      @force = force
      @processed_files = []
      @total_changes = { new: {}, updated: {} }
    end

    def process_all_files(&block)
      files = Dir.glob(Rails.root.join('db', 'seed', 'updates', '*.csv')).sort

      files.each do |file|
        if (result = import_csv(file))
          merge_results(result)
          block.call(result) if block_given?
        end
      end

      if @processed_files.any?
        print_summary
      end
    end

    private

    def merge_results(result)
      result[:new].each do |type, records|
        @total_changes[:new][type] ||= []
        @total_changes[:new][type].concat(records)
      end

      result[:updated].each do |type, records|
        @total_changes[:updated][type] ||= []
        @total_changes[:updated][type].concat(records)
      end
    end

    def import_csv(file_path)
      filename = File.basename(file_path)
      if already_imported?(filename)
        log_verbose("Skipping #{filename} - already imported\n") if @verbose
        return
      end

      importer = create_importer(filename, file_path)
      return unless importer

      @processed_files << filename
      mode_text = @test_mode ? '🛠️ Testing' : 'Processing'
      force_text = @force ? ' (Force mode)' : ''

      if @verbose
        log_header("#{mode_text}#{force_text}: #{filename}", "-")
        puts "\n"
      end

      result = if @test_mode
                 test_import(importer)
               else
                 importer.import
               end

      log_import(filename, result)
      result
    end

    def test_import(importer)
      # In test mode, we simulate the import and record what would happen
      simulated_result = importer.simulate_import

      if @test_transaction
        simulated_result.each do |operation, type_records|
          type_records.each do |type, records|
            records.each do |record_attrs|
              @test_transaction.add_change(
                model: type.to_s.classify.constantize,
                attributes: record_attrs,
                operation: operation
              )
            end
          end
        end
      end

      simulated_result
    end

    def create_importer(filename, file_path)
      # This pattern matches both singular and plural: character(s), weapon(s), summon(s)
      match = filename.match(/\A\d{8}-(character(?:s)?|weapon(?:s)?|summon(?:s)?)-\d+\.csv\z/)
      return unless match

      matched_type = match[1]
      singular_type = matched_type.sub(/s$/, '')
      importer_class = "Granblue::Importers::#{singular_type.capitalize}Importer".constantize

      importer_class.new(
        file_path,
        test_mode: @test_mode,
        verbose: @verbose,
        logger: self
      )
    rescue NameError
      log_warning "No importer found for type: #{singular_type}"
      nil
    end

    def already_imported?(filename)
      return false if @force
      DataVersion.imported?(filename)
    end

    def log_import(filename, result)
      return if @test_mode

      DataVersion.mark_as_imported(filename)
      log_import_results(result) if @verbose
    end

    def log_import_results(result)
      result[:new].each do |type, records|
        log_verbose "Created #{records.size} new #{type.pluralize}" if records.any?
      end
      result[:updated].each do |type, records|
        log_verbose "Updated #{records.size} existing #{type.pluralize}" if records.any?
      end
    end

    def print_summary
      return if @processed_files.empty?

      log_header("Processed files:")
      puts "\n"
      @processed_files.each { |file| log_step "  • #{file}" }
    end

    def print_change_summary(action, changes)
      changes.each do |type, records|
        next if records.empty?
        log_step "  • #{action} #{records.size} #{type} #{records.size == 1 ? 'record' : 'records'}"
      end
    end
  end
end
