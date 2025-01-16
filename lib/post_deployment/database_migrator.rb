# frozen_string_literal: true

require_relative '../logging_helper'

module PostDeployment
  class DatabaseMigrator
    include LoggingHelper

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

    def simulate_migrations
      log_step "TEST MODE: Would run pending migrations..."

      # Check schema migrations
      pending_schema_migrations = ActiveRecord::Base.connection.pool.migration_context.needs_migration?
      schema_migrations = ActiveRecord::Base.connection.pool.migration_context.migrations

      # Check data migrations
      data_migrations_path = DataMigrate.config.data_migrations_path
      data_migration_context = DataMigrate::MigrationContext.new(data_migrations_path)
      pending_data_migrations = data_migration_context.needs_migration?
      data_migrations = data_migration_context.migrations

      if pending_schema_migrations || pending_data_migrations
        if schema_migrations.any?
          log_step "Would apply #{schema_migrations.size} pending schema migrations:"
          schema_migrations.each do |migration|
            log_step "  • #{migration.name}"
          end
        end

        if data_migrations.any?
          log_step "\nWould apply #{data_migrations.size} pending data migrations:"
          data_migrations.each do |migration|
            log_step "  • #{migration.name}"
          end
        end
      else
        log_step "No pending migrations."
      end
    end

    def perform_migrations
      ActiveRecord::Migration.verbose = @verbose

      # Run schema migrations
      schema_version = ActiveRecord::Base.connection.pool.migration_context.current_version
      ActiveRecord::Tasks::DatabaseTasks.migrate
      new_schema_version = ActiveRecord::Base.connection.pool.migration_context.current_version

      # Run data migrations
      data_migrations_path = DataMigrate.config.data_migrations_path
      data_migration_context = DataMigrate::MigrationContext.new(data_migrations_path)

      data_version = data_migration_context.current_version
      data_migration_context.migrate
      new_data_version = data_migration_context.current_version

      if schema_version == new_schema_version && data_version == new_data_version
        log_step "No pending migrations."
      else
        if schema_version != new_schema_version
          log_step "Migrated schema from version #{schema_version} to #{new_schema_version}"
        end
        if data_version != new_data_version
          log_step "Migrated data from version #{data_version} to #{new_data_version}"
        end
      end
    end
  end
end
