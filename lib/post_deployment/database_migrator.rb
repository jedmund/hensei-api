# frozen_string_literal: true

require_relative '../logging_helper'

module PostDeployment
  class DatabaseMigrator
    include LoggingHelper

    class CombinedMigration
      attr_reader :version, :name, :migration, :type

      def initialize(version, name, migration, type)
        @version = version
        @name = name
        @migration = migration
        @type = type
      end

      def schema_migration?
        @type == :schema
      end

      def data_migration?
        @type == :data
      end
    end

    def initialize(test_mode:, verbose:)
      @test_mode = test_mode
      @verbose = verbose
    end

    def run
      log_header 'Running database migrations...', '-'
      puts "\n"

      if @test_mode
        simulate_migrations
      else
        perform_migrations
      end
    end

    private

    def collect_pending_migrations
      # Collect schema migrations
      schema_context = ActiveRecord::Base.connection.pool.migration_context
      schema_migrations = schema_context.migrations.map do |migration|
        CombinedMigration.new(
          migration.version,
          migration.name,
          migration,
          :schema
        )
      end

      # Collect data migrations
      data_migrations_path = DataMigrate.config.data_migrations_path
      data_migration_context = DataMigrate::MigrationContext.new(data_migrations_path)
      data_migrations = data_migration_context.migrations.map do |migration|
        CombinedMigration.new(
          migration.version,
          migration.name,
          migration,
          :data
        )
      end

      # Combine and sort all migrations by version
      (schema_migrations + data_migrations).sort_by(&:version)
    end

    def simulate_migrations
      pending_migrations = collect_pending_migrations

      if pending_migrations.any?
        log_step "TEST MODE: Would run #{pending_migrations.size} pending migrations in this order:"
        pending_migrations.each do |migration|
          type = migration.schema_migration? ? 'schema' : 'data'
          log_step "  • [#{type}] #{migration.name} (#{migration.version})"
        end
      else
        log_step 'No pending migrations.'
      end
    end

    def perform_migrations
      ActiveRecord::Migration.verbose = @verbose
      pending_migrations = collect_pending_migrations

      return log_step 'No pending migrations.' if pending_migrations.empty?

      schema_context = ActiveRecord::Base.connection.pool.migration_context
      data_context = DataMigrate::MigrationContext.new(DataMigrate.config.data_migrations_path)

      initial_schema_version = schema_context.current_version
      initial_data_version = data_context.current_version

      pending_migrations.each do |combined_migration|
        if combined_migration.schema_migration?
          # Execute schema migration using Rails migration context
          schema_context.run(:up, combined_migration.version)
        else
          # Execute data migration using data-migrate context
          data_context.run(:up, combined_migration.version)
        end
      end

      final_schema_version = schema_context.current_version
      final_data_version = data_context.current_version

      if initial_schema_version != final_schema_version
        log_step "Migrated schema from version #{initial_schema_version} to #{final_schema_version}"
      end

      if initial_data_version != final_data_version
        log_step "Migrated data from version #{initial_data_version} to #{final_data_version}"
      end
    end
  end
end
