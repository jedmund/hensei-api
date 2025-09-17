# frozen_string_literal: true

class ConvertGameRawColumnsToJsonb < ActiveRecord::Migration[8.0]
  def up
    tables = %w[characters summons weapons]

    tables.each do |table|
      # Create a backup of game_raw_en to prevent data loss
      add_column table, :game_raw_en_backup, :text
      execute("UPDATE #{table} SET game_raw_en_backup = game_raw_en WHERE game_raw_en IS NOT NULL")

      # Verify backup integrity
      backup_validation = execute(<<~SQL).first
        SELECT COUNT(*) AS missing_backups
        FROM #{table}
        WHERE game_raw_en IS NOT NULL#{' '}
        AND game_raw_en_backup IS NULL
      SQL

      if backup_validation['missing_backups'].to_i.positive?
        raise ActiveRecord::MigrationError, "Backup failed for #{table}. Aborting migration."
      end

      # Convert game_raw_en with data validation
      begin
        execute("ALTER TABLE #{table} ALTER COLUMN game_raw_en TYPE JSONB USING game_raw_en::JSONB")
      rescue StandardError => e
        # Find and report problematic rows
        create_invalid_rows_table(table)
        invalid_count = execute("SELECT COUNT(*) FROM invalid_#{table}_rows").first['count']

        raise ActiveRecord::MigrationError, <<~ERROR
          Failed to convert game_raw_en in #{table} to JSONB.
          #{invalid_count} rows contain invalid JSON.
          Original error: #{e.message}
          See temporary table invalid_#{table}_rows for details.
        ERROR
      end

      # Simply convert game_raw_jp (empty column)
      execute("ALTER TABLE #{table} ALTER COLUMN game_raw_jp TYPE JSONB USING COALESCE(game_raw_jp::JSONB, 'null'::JSONB)")

      # Add comment to indicate column purpose
      execute("COMMENT ON COLUMN #{table}.game_raw_en IS 'JSON data from game (English)'")
      execute("COMMENT ON COLUMN #{table}.game_raw_jp IS 'JSON data from game (Japanese)'")
    end

    # Leave a note about backup columns in migration output
    say 'Migration successful. Backup columns (game_raw_en_backup) remain for verification.'
    say 'Run a separate migration to remove backup columns after verification.'
  end

  def down
    tables = %w[characters summons weapons]

    tables.each do |table|
      # Check if we can restore from backup
      if column_exists?(table, :game_raw_en_backup)
        say "Restoring #{table}.game_raw_en from backup..."
        execute("UPDATE #{table} SET game_raw_en = game_raw_en_backup WHERE game_raw_en_backup IS NOT NULL")
        remove_column table, :game_raw_en_backup
      end

      # Convert both columns back to TEXT
      execute("ALTER TABLE #{table} ALTER COLUMN game_raw_en TYPE TEXT")
      execute("ALTER TABLE #{table} ALTER COLUMN game_raw_jp TYPE TEXT")
    end
  end

  private

  def create_invalid_rows_table(table)
    execute(<<~SQL)
      CREATE TEMPORARY TABLE invalid_#{table}_rows AS
      SELECT id, game_raw_en#{' '}
      FROM #{table}
      WHERE game_raw_en IS NOT NULL
      AND pg_typeof(game_raw_en) = 'text'::regtype
      AND (
        TRIM(game_raw_en) = ''#{' '}
        OR#{' '}
        (game_raw_en::JSONB) IS NULL
      );
    SQL
  end
end
