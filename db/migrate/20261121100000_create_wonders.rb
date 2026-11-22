# frozen_string_literal: true

# Wonders (大事なもの): the account-level items players earn in the game. The
# catalogue (categories, Wonders, their effects, per-level bonuses and Seal
# evolution caps) is seeded by a data migration; users record theirs in
# collection_wonders, and teams snapshot them into party_wonders when created.
class CreateWonders < ActiveRecord::Migration[8.1]
  def change
    create_table :wonder_categories, id: :uuid do |t|
      t.string :granblue_id, null: false
      t.string :name_en, null: false
      t.string :name_jp
      t.integer :category_type, null: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
      t.index :granblue_id, unique: true
    end

    create_table :wonders, id: :uuid do |t|
      t.string :granblue_id, null: false
      t.references :wonder_category, type: :uuid, null: false, foreign_key: true
      t.string :name_en, null: false
      t.string :name_jp
      t.text :description_en
      t.text :description_jp
      t.string :kind, null: false, default: 'fixed'
      t.integer :max_level
      t.integer :max_evolution, null: false, default: 0
      t.integer :element
      t.boolean :battle_relevant, null: false, default: false
      t.boolean :hidden_in_unite_and_fight, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
      t.index :granblue_id, unique: true
    end

    # action_id is the game's effect id, shared between Wonders with the same
    # effect. It's null for effects known only from the wiki.
    create_table :wonder_effects, id: :uuid do |t|
      t.integer :action_id
      t.text :text_en
      t.text :text_jp
      t.jsonb :details, null: false, default: {}
      t.timestamps
      t.index :action_id, unique: true, where: 'action_id IS NOT NULL'
    end

    create_table :wonder_effect_links, id: :uuid do |t|
      t.references :wonder, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :wonder_effect, type: :uuid, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
      t.index %i[wonder_id position], unique: true
    end

    # What each level adds; the bonuses at level N are the sum up to N.
    create_table :wonder_level_bonuses, id: :uuid do |t|
      t.references :wonder, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :level, null: false
      t.string :stat, null: false
      t.integer :value, null: false
      t.timestamps
      t.index %i[wonder_id level], unique: true
    end

    create_table :wonder_evolution_caps, id: :uuid do |t|
      t.references :wonder, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :evolution, null: false
      t.integer :max_level, null: false
      t.timestamps
      t.index %i[wonder_id evolution], unique: true
    end

    create_table :collection_wonders, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :wonder, type: :uuid, null: false, foreign_key: true
      t.boolean :active, null: false, default: true
      t.integer :level
      t.integer :evolution
      t.integer :possession
      t.string :image
      t.jsonb :imported_bonuses
      t.datetime :synced_at
      t.timestamps
      t.index %i[user_id wonder_id], unique: true
    end

    create_table :party_wonders, id: :uuid do |t|
      t.references :party, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :wonder, type: :uuid, null: false, foreign_key: true
      t.integer :level
      t.integer :evolution
      t.integer :possession
      t.string :image
      t.timestamps
      t.index %i[party_id wonder_id], unique: true
    end
  end
end
