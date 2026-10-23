# frozen_string_literal: true

# Adds the wiki_cargo source kind: gbf.wiki Cargo query rows, one shared row per Cargo table
# (key = table name), so a backfill parses a stored copy instead of querying the wiki again.
class AddWikiCargoSourceKind < ActiveRecord::Migration[8.1]
  KINDS = %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_status_list jp_skill_text
             expanded transclusion family_template icon_snapshot].freeze

  def up
    replace_kinds(KINDS + %w[wiki_cargo])
  end

  def down
    execute "DELETE FROM sources WHERE kind = 'wiki_cargo'"
    replace_kinds(KINDS)
  end

  private

  def replace_kinds(kinds)
    remove_check_constraint :sources, name: 'sources_kind'
    add_check_constraint :sources, "kind IN (#{kinds.map { |kind| connection.quote(kind) }.join(', ')})", name: 'sources_kind'
  end
end
