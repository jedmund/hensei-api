# frozen_string_literal: true

# Stored gbf.wiki inputs for the weapon-skill build. Fetching is one explicit step
# (granblue:fetch_weapon_sources); parsing and building only read these rows.
class CreateWeaponSources < ActiveRecord::Migration[8.1]
  def change
    create_table :weapon_sources, id: :uuid do |t|
      t.references :weapon, type: :uuid, foreign_key: { on_delete: :cascade }, null: true, index: false
      t.string :kind, null: false
      t.string :key, null: false
      t.text :body, null: false
      t.string :sha256, null: false
      t.datetime :fetched_at, null: false
      t.string :page_kind
      t.timestamps
    end

    # Unique per weapon. Pages no weapon owns (family templates, key series pages) have a
    # null weapon_id and are unique on (kind, key).
    add_index :weapon_sources, %i[weapon_id kind key], unique: true, where: "weapon_id IS NOT NULL",
                                                       name: "index_weapon_sources_on_weapon_kind_key"
    add_index :weapon_sources, %i[kind key], unique: true, where: "weapon_id IS NULL",
                                             name: "index_weapon_sources_on_shared_kind_key"
    add_index :weapon_sources, %i[kind key fetched_at], name: "index_weapon_sources_lookup"
    add_check_constraint :weapon_sources,
                         "kind IN ('wiki_raw', 'expanded', 'transclusion', 'family_template')",
                         name: "weapon_sources_kind"
    add_check_constraint :weapon_sources,
                         "page_kind IS NULL OR page_kind IN ('inline', 'series_template', 'key_determined')",
                         name: "weapon_sources_page_kind"
  end
end
