# frozen_string_literal: true

# Weapon and summon game payloads keep only the item's data (Granblue::GamePayload.sanitize_item),
# as the models now store them. Cleans the stored rows in place: batched by id, idempotent
# (a row already clean is left alone), with SQL updates, so no model callbacks or build jobs run.
# Logs counts only. A no-op once the columns are dropped (20261023100000).
class SanitizeItemGamePayloads < ActiveRecord::Migration[8.1]
  BATCH = 200
  TABLES = %w[weapons summons].freeze
  COLUMNS = %w[game_raw_en game_raw_jp].freeze

  def up
    TABLES.product(COLUMNS).each do |table, column|
      next say("#{table}.#{column} is gone; nothing to clean") unless db.column_exists?(table, column)

      checked, cleaned = sanitize(table, column)
      say "#{table}.#{column}: #{checked} checked, #{cleaned} cleaned"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def db = ActiveRecord::Base.connection

  def sanitize(table, column)
    checked = 0
    cleaned = 0
    last_id = nil
    loop do
      rows = db.select_all(<<~SQL.squish).cast_values
        SELECT id, #{column} FROM #{table}
        WHERE jsonb_typeof(#{column}) = 'object' #{"AND id > #{db.quote(last_id)}" if last_id}
        ORDER BY id LIMIT #{BATCH}
      SQL
      break if rows.empty?

      rows.each do |id, payload|
        checked += 1
        kept = Granblue::GamePayload.sanitize_item(payload)
        next if kept == payload

        db.exec_update("UPDATE #{table} SET #{column} = #{db.quote(JSON.generate(kept))}::jsonb WHERE id = #{db.quote(id)}")
        cleaned += 1
      end
      last_id = rows.last.first
    end
    [checked, cleaned]
  end
end
