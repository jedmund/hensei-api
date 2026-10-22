# frozen_string_literal: true

# Date every stored wikitext that has no fetch date. The real fetch time is
# unknown for these rows, so they get the day fetch dates started being recorded.
# Weapons' existing wiki_raw_fetched_at values are real and are kept.
class BackfillWikiFetchDates < ActiveRecord::Migration[8.1]
  BACKFILL_AT = Time.utc(2026, 10, 15)
  COLUMNS = { wiki_raw: :wiki_raw_fetched_at, wiki_raw_jp: :wiki_raw_jp_fetched_at }.freeze

  def up
    [Weapon, Summon, Character].each do |model|
      model.reset_column_information
      COLUMNS.each do |text, stamp|
        # characters' columns are dropped later (20261022090000); their data lives in `sources`.
        next unless connection.column_exists?(model.table_name, text)

        model.where.not(text => [nil, '']).where(stamp => nil).update_all(stamp => BACKFILL_AT)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
