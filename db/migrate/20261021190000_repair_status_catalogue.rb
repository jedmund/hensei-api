# frozen_string_literal: true

# One status per name. The catalogue held 1,568 rows for 558 names, because the builder keyed
# rows by the game's ailment ids, which it had paired with the wiki's names by position (the
# lists aren't parallel). CharacterSkills::StatusCatalogueRepair merges each name onto one row
# (effects move to it), recomputes family/level, and fills name_key: the name as
# Status.normalize_name computes it in Ruby (squished, Unicode-downcased), so lookups agree
# whatever the database's locale. A unique index on name_key keeps duplicates out.
#
# A trailing number on a wiki status name is the icon variant, not part of the name ("DEF Down 4"
# = DEF Down for 4 turns, the game's 1020_14), so numbered rows merge into their status and the
# number moves to the effects: skill_effects.status_variant, with status_variant_kind (turns |
# level | uses) and the exact display id (game_status_id) filled by the next build.
# statuses.variant_kind is the family's kind; statuses.game_status_id the base display id
# (ability_detail's `status`, also the icon id). Several statuses can share one, so it isn't unique.
# statuses.description holds the game's own description (gbf.wiki Module:StatusList, D33).
#
# The repair runs inline, before the index that depends on it. The next skill build refreshes
# categories and ids from the stored sources. Merged rows can't be restored: down raises.
class RepairStatusCatalogue < ActiveRecord::Migration[8.1]
  def up
    add_column :statuses, :game_status_id, :string
    add_index :statuses, :game_status_id
    add_column :statuses, :name_key, :string
    add_column :statuses, :variant_kind, :string
    add_column :statuses, :description, :text
    add_column :skill_effects, :status_variant, :integer
    add_column :skill_effects, :status_variant_kind, :string
    add_column :skill_effects, :game_status_id, :string

    counts = CharacterSkills::StatusCatalogueRepair.call(connection)
    say "Merged #{counts[:merged_names]} duplicate names: #{counts[:deleted]} statuses removed, " \
        "#{counts[:effects_repointed]} effects repointed, #{counts[:variants_set]} effect variants set, " \
        "#{counts[:renamed]} renamed; family/level fixed on #{counts[:families_fixed]}"

    change_column_null :statuses, :name_key, false
    add_index :statuses, :name_key, unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'merged duplicate statuses and their effects can\'t be split again'
  end
end
