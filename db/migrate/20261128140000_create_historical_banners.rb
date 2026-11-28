# frozen_string_literal: true

# The game's past banners, read from gbf.wiki's Banner History (BannerHistory::Import),
# and the items each featured: rate-ups on galas, featured items on other draws, a
# collab's own items. Rebuilt from the cached wiki pages, so they can be dropped and
# imported again.
class CreateHistoricalBanners < ActiveRecord::Migration[8.1]
  def change
    create_table :historical_banners, id: :uuid do |t|
      # start, type and name: unique across the history
      t.string :key, null: false
      t.string :kind, null: false
      # The spark maker's pool: premium, flash, legend or collab
      t.string :pool, null: false
      t.string :name
      t.datetime :starts_at, null: false
      # nil for the banner still running, or one before a stretch the wiki doesn't cover
      t.datetime :ends_at
      # The SSR total, in percent: 6 on galas, 3 otherwise
      t.decimal :ssr_rate
      t.string :source_key, null: false
      t.timestamps
    end
    add_index :historical_banners, :key, unique: true
    add_index :historical_banners, %i[pool starts_at]

    create_table :historical_banner_items, id: :uuid do |t|
      t.references :historical_banner, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      # A weapon's or summon's granblue_id, as the gacha catalogue has it; a character is
      # recorded as the weapon that recruits them
      t.string :granblue_id, null: false
      t.string :item_type, null: false
      # rate_up, featured, collab, zodiac or pool
      t.string :role, null: false
      t.string :wiki_name, null: false
      t.timestamps
    end
    add_index :historical_banner_items, %i[historical_banner_id granblue_id role], unique: true,
                                                                                   name: 'index_historical_banner_items_unique'
    add_index :historical_banner_items, :granblue_id
  end
end
