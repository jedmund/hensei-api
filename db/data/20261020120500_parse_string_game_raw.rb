# frozen_string_literal: true

# The extractor import stored game data as body.to_json in a jsonb column, so
# game_raw_en/jp held a JSON string instead of an object and nothing could read
# it. Parse those strings back into objects, and turn JSON null into SQL NULL so
# coverage queries count missing data honestly. A string that isn't valid JSON
# is logged and left alone.
class ParseStringGameRaw < ActiveRecord::Migration[8.0]
  TABLES = %w[characters weapons summons].freeze
  COLUMNS = %w[game_raw_en game_raw_jp].freeze

  def up
    TABLES.product(COLUMNS).each do |table, column|
      parsed, skipped = parse_strings(table, column)
      nulled = execute(<<~SQL.squish).cmd_tuples
        UPDATE #{table} SET #{column} = NULL WHERE jsonb_typeof(#{column}) = 'null'
      SQL
      say "#{table}.#{column}: #{parsed} strings parsed, #{skipped} skipped, #{nulled} JSON nulls cleared"
    end
  end

  def down
    # No-op: the strings were unreadable copies of the same data.
  end

  private

  def parse_strings(table, column)
    rows = select_rows(<<~SQL.squish)
      SELECT id, #{column} #>> '{}' FROM #{table} WHERE jsonb_typeof(#{column}) = 'string'
    SQL
    rows.each_with_object([0, 0]) do |(id, text), counts|
      value = JSON.parse(text)
      unless value.is_a?(Hash) || value.is_a?(Array)
        counts[1] += 1
        next
      end

      execute(<<~SQL.squish)
        UPDATE #{table} SET #{column} = #{quote(JSON.generate(value))}::jsonb WHERE id = #{quote(id)}
      SQL
      counts[0] += 1
    rescue JSON::ParserError
      say "#{table}.#{column}: #{id} is not JSON, left as is"
      counts[1] += 1
    end
  end
end
