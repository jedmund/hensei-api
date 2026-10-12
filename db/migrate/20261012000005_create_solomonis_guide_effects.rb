# frozen_string_literal: true

# The Evoking Solomonis guidebook effect catalogue, keyed by the game's
# status_id, and each run's guidebook (the effects held at the end, with
# stack counts).
class CreateSolomonisGuideEffects < ActiveRecord::Migration[8.1]
  def change
    create_table :solomonis_guide_effects, id: :uuid do |t|
      t.integer :granblue_id, null: false
      t.string :rarity, null: false
      t.boolean :stackable, null: false, default: false
      t.text :name_en
      t.text :name_jp
      t.integer :icon_category
      t.integer :icon_type
      t.string :target_type
      t.integer :target_values, array: true, null: false, default: []
      t.references :character, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :availability
      # null: no wiki match yet; []: matched, no tags
      t.string :type_tags, array: true
      t.string :effect_tags, array: true
      # Rows added by imports wait for a human to fill the other language and tags.
      t.boolean :needs_review, null: false, default: false
      t.timestamps
      t.index :granblue_id, unique: true
      t.index :rarity
      t.check_constraint 'name_en IS NOT NULL OR name_jp IS NOT NULL', name: 'solomonis_guide_effects_name_present'
    end

    create_table :expedition_guide_effects, id: :uuid do |t|
      t.references :party, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :solomonis_guide_effect, type: :uuid, null: false, foreign_key: true
      t.integer :count, null: false, default: 1
      t.string :display_value
      t.integer :acquired_order
      t.boolean :inherited, null: false, default: false
      t.string :note
      t.timestamps
      t.index %i[party_id solomonis_guide_effect_id], unique: true,
                                                      name: 'index_expedition_guide_effects_on_party_and_effect'
      t.index :party_id, unique: true, where: 'inherited', name: 'index_expedition_guide_effects_one_inherited'
      t.check_constraint 'count >= 1', name: 'expedition_guide_effects_count_positive'
    end
  end
end
