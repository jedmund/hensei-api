# frozen_string_literal: true

module Granblue
  class DataImporter
    def initialize(test_mode: false, verbose: false)
      @test_mode = test_mode
      @verbose = verbose
      @import_logs = []
    end

    def process_all_files(&block)
      files = Dir.glob(Rails.root.join('db', 'seed', 'updates', '*.csv')).sort

      files.each do |file|
        if (new_records = import_csv(file))
          block.call(new_records) if block_given?
        end
      end

      print_summary if @test_mode
    end

    private

    def import_csv(file_path)
      filename = File.basename(file_path)
      return if already_imported?(filename)

      importer = create_importer(filename, file_path)
      return unless importer

      log_info "Processing #{filename} in #{@test_mode ? 'TEST' : 'LIVE'} mode..."
      new_records = importer.import
      log_import(filename)
      log_info "Successfully processed #{filename}"
      new_records
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
      log_info "No importer found for type: #{singular_type}"
      nil
    end

    def already_imported?(filename)
      DataVersion.imported?(filename)
    end

    def log_import(filename)
      return if @test_mode
      DataVersion.mark_as_imported(filename)
    end

    def log_operation(operation)
      if @test_mode
        @import_logs << operation
        log_info "[TEST MODE] Would perform: #{operation}"
      end
    end

    def print_summary
      log_info "\nTest Mode Summary:"
      log_info "Would perform #{@import_logs.size} operations"
      if @import_logs.any?
        log_info 'Sample of operations:'
        @import_logs.first(3).each { |log| log_info "- #{log}" }
        log_info '...' if @import_logs.size > 3
      end
    end

    def log_info(message)
      puts message if @verbose || @test_mode
    end
  end
end
