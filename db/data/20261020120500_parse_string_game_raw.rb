# frozen_string_literal: true

# The extractor import stored game data as body.to_json in a jsonb column, so
# game_raw_en/jp held a JSON string instead of an object and nothing could read
# it. Parse those strings back into objects, and turn JSON null into SQL NULL so
# coverage queries count missing data honestly. A row that can't be repaired is
# logged by id, counted as skipped and left alone; it never fails the deploy.
class ParseStringGameRaw < ActiveRecord::Migration[8.0]
  TABLES = %w[characters weapons summons].freeze
  COLUMNS = %w[game_raw_en game_raw_jp].freeze

  def up
    TABLES.product(COLUMNS).each do |table, column|
      # characters' columns are dropped later (20261022090000).
      next unless db.column_exists?(table, column)

      parsed, skipped = parse_strings(table, column)
      nulled = db.exec_update("UPDATE #{table} SET #{column} = NULL WHERE jsonb_typeof(#{column}) = 'null'")
      say "#{table}.#{column}: #{parsed} strings parsed, #{skipped} skipped, #{nulled} JSON nulls cleared"
    end
  end

  def down
    # No-op: the strings were unreadable copies of the same data.
  end

  private

  def db
    ActiveRecord::Base.connection
  end

  def parse_strings(table, column)
    rows = db.select_rows("SELECT id, #{column} #>> '{}' FROM #{table} WHERE jsonb_typeof(#{column}) = 'string'")
    rows.each_with_object([0, 0]) do |(id, text), counts|
      if repair(table, column, id, text)
        counts[0] += 1
      else
        counts[1] += 1
      end
    end
  end

  # true when the row now holds the parsed object.
  def repair(table, column, id, text)
    value = JSON.parse(text)
    return false unless value.is_a?(Hash) || value.is_a?(Array)

    ActiveRecord::Base.transaction(requires_new: true) do
      db.exec_update(
        "UPDATE #{table} SET #{column} = #{db.quote(JSON.generate(value))}::jsonb WHERE id = #{db.quote(id)}"
      )
    end
    true
  rescue JSON::ParserError, JSON::GeneratorError, ActiveRecord::StatementInvalid => e
    say "#{table}.#{column}: skipped #{id} (#{e.class})"
    false
  end
end
