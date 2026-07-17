# frozen_string_literal: true

# #62 phase 3: the boost-type registry. Panel lines, display caps, amplifiability,
# and hidden-key semantics move from code constants to data (DB rows override; the
# constants remain as code defaults so a bare database still calculates).
class ExtendBoostTypeRegistry < ActiveRecord::Migration[8.0]
  def change
    change_table :weapon_skill_boost_types, bulk: true do |t|
      t.decimal :display_cap, precision: 12, scale: 2 # panel display cap (orange at >=)
      t.boolean :amplifiable                          # nil = default (true); false = never enhanced
      t.boolean :hidden, default: false, null: false  # header-only boosts (elemental_enhance)
    end

    create_table :panel_lines, id: :uuid do |t|
      t.string :boost_type, null: false
      t.string :series # nil = series-agnostic; atk splits into normal/omega/odious/ex
      t.string :label_en, null: false
      t.string :slug, null: false # badge slug (skill-label images)
      t.string :group_name, null: false
      t.integer :position, null: false
      t.datetime :manually_edited_at
      t.timestamps
      t.index %i[boost_type series], unique: true
      t.index :position
    end

    # Bahamut/Celestial/Ultima/Destroyer skills are never summon-boosted.
    add_column :weapon_series, :summon_boosted, :boolean
  end
end
