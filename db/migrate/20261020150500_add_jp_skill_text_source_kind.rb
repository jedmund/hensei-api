# frozen_string_literal: true

# jp_skill_text (D38): curated Japanese skill names and descriptions for a character row
# that no fetched page covers (e.g. Lecia's style shift, from the official blog). JSON.
class AddJpSkillTextSourceKind < ActiveRecord::Migration[8.1]
  KINDS = %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_status_list].freeze

  def up
    replace_kinds(KINDS + %w[jp_skill_text])
  end

  def down
    execute "DELETE FROM sources WHERE kind = 'jp_skill_text'"
    replace_kinds(KINDS)
  end

  private

  def replace_kinds(kinds)
    remove_check_constraint :sources, name: 'sources_kind'
    add_check_constraint :sources, "kind IN (#{kinds.map { |kind| connection.quote(kind) }.join(', ')})", name: 'sources_kind'
  end
end
