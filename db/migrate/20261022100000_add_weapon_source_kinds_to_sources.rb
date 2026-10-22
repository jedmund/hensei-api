# frozen_string_literal: true

# Makes room in `sources` for what PR 7b moves there (D34/D35):
#   - the weapon-skill build's inputs from weapon_sources: kinds expanded, transclusion and
#     family_template (wiki_raw is already a kind), and page_kind, which the fetch decides from
#     a weapon page's template and the build reads;
#   - the character skill icon snapshot (kind icon_snapshot, one shared row).
# The build looks pages up by (kind, key) whatever their owner, newest fetch first, so that
# lookup gets an index like weapon_sources had.
class AddWeaponSourceKindsToSources < ActiveRecord::Migration[8.1]
  KINDS = %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_status_list jp_skill_text].freeze
  NEW_KINDS = %w[expanded transclusion family_template icon_snapshot].freeze
  PAGE_KINDS = %w[inline series_template key_determined].freeze

  def up
    replace_kinds(KINDS + NEW_KINDS)
    add_column :sources, :page_kind, :string
    add_check_constraint :sources,
                         "page_kind IS NULL OR page_kind IN (#{PAGE_KINDS.map { |kind| connection.quote(kind) }.join(', ')})",
                         name: 'sources_page_kind'
    add_index :sources, %i[kind key fetched_at], name: 'index_sources_on_kind_key_fetched_at'
  end

  def down
    remove_index :sources, name: 'index_sources_on_kind_key_fetched_at'
    remove_check_constraint :sources, name: 'sources_page_kind'
    remove_column :sources, :page_kind
    execute "DELETE FROM sources WHERE kind IN (#{NEW_KINDS.map { |kind| connection.quote(kind) }.join(', ')})"
    replace_kinds(KINDS)
  end

  private

  def replace_kinds(kinds)
    remove_check_constraint :sources, name: 'sources_kind'
    add_check_constraint :sources, "kind IN (#{kinds.map { |kind| connection.quote(kind) }.join(', ')})", name: 'sources_kind'
  end
end
