# frozen_string_literal: true

# #62 phase 4/5: the family registry ({{Weapon Skills/*}} — 133 families) and row
# provenance. A family row carries what the wiki's WsBox header declares: whether
# summon auras boost it, which panel boosts it grants, and its icon stems per
# series×size (identity only — values never come from icons). Provenance marks
# where each data row's numbers came from, so a template re-import can never
# clobber a golden-derived correction.
class CreateWeaponSkillFamilies < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_skill_families, id: :uuid do |t|
      t.string :name, null: false, index: { unique: true }
      t.boolean :aura_boostable
      t.jsonb :boosts, default: [], null: false     # WsBox boost1..N labels, in order
      t.jsonb :icon_stems, default: {}, null: false # {"normal" => {"big" => "ws_skill_atk_*_3.png", …}, …}
      t.string :color
      t.datetime :imported_at
      t.datetime :manually_edited_at
      t.timestamps
    end

    add_column :weapon_skill_data, :provenance, :string
    add_column :weapon_skill_effects, :provenance, :string
    reversible do |dir|
      dir.up do
        execute "UPDATE weapon_skill_data SET provenance = 'manual' WHERE manually_edited_at IS NOT NULL"
        execute "UPDATE weapon_skill_effects SET provenance = 'manual' WHERE manually_edited_at IS NOT NULL"
      end
    end
  end
end
