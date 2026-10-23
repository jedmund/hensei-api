# frozen_string_literal: true

# The game's live draw banners and their published per-item rates, fetched
# from the game by script/fetch_gacha_rates.rb. Rates are stored as the game
# shows them (percentages truncated to 3 places); the simulator scales them to
# each rarity's stated total.
class CreateGachaBanners < ActiveRecord::Migration[8.1]
  def change
    create_table :gacha_banners, id: :uuid do |t|
      t.string :game_id, null: false
      t.string :name
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # Each tab's stated rarity totals, as fractions: { "1" => { "3" => "0.03", ... } }
      t.jsonb :rarity_rates, null: false, default: {}
      t.datetime :fetched_at, null: false
      t.timestamps
      t.index :game_id, unique: true
      t.index :starts_at
    end

    create_table :gacha_banner_rates, id: :uuid do |t|
      t.references :gacha_banner, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      # 1 is the ordinary draw, 2 the 10-part's guaranteed SR or better
      t.integer :tab, null: false
      t.string :reward_id, null: false
      t.integer :rarity, null: false
      t.string :category, null: false
      # The displayed percentage
      t.decimal :percent, null: false
      t.boolean :rate_up, null: false, default: false
      t.string :name
      t.index %i[gacha_banner_id tab reward_id], unique: true, name: 'index_gacha_banner_rates_on_banner_tab_reward'
    end
  end
end
