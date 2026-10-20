# frozen_string_literal: true

# Character skills belong to a character row, not a granblue_id. A style shift shares
# its base character's granblue_id but has its own abilities, so keying by granblue_id
# gave both rows one skill set. Existing slots go to the base row (style_swap: false);
# style rows start empty and are built from their own sources.
#
# The backfill runs inline, between adding the column and making it NOT NULL, so it
# doesn't depend on how data migrations interleave with schema ones.
class AddCharacterIdToCharacterSkills < ActiveRecord::Migration[8.1]
  def up
    add_reference :character_skills, :character, type: :uuid, foreign_key: true, null: true, index: false

    # The backfill joins on (granblue_id, style_swap: false); two base rows would give a
    # skill two owners, and which one UPDATE … FROM picks is undefined.
    ambiguous = select_values(<<~SQL.squish)
      SELECT c.granblue_id FROM characters c
      WHERE c.style_swap = false
        AND EXISTS (SELECT 1 FROM character_skills cs WHERE cs.character_granblue_id = c.granblue_id)
      GROUP BY c.granblue_id HAVING count(*) > 1 ORDER BY c.granblue_id
    SQL
    if ambiguous.any?
      raise "character_skills can't be backfilled: more than one base (style_swap: false) row for #{ambiguous.join(', ')}"
    end

    execute <<~SQL.squish
      UPDATE character_skills cs SET character_id = c.id
      FROM characters c
      WHERE c.granblue_id = cs.character_granblue_id AND c.style_swap = false
    SQL

    orphans = select_value("SELECT count(*) FROM character_skills WHERE character_id IS NULL").to_i
    if orphans.positive?
      say "Deleting #{orphans} character skills with no base character row"
      execute <<~SQL.squish
        DELETE FROM skill_effects WHERE character_skill_version_id IN (
          SELECT v.id FROM character_skill_versions v
          JOIN character_skills cs ON cs.id = v.character_skill_id WHERE cs.character_id IS NULL)
      SQL
      execute <<~SQL.squish
        DELETE FROM character_skill_version_links WHERE from_version_id IN (
          SELECT v.id FROM character_skill_versions v
          JOIN character_skills cs ON cs.id = v.character_skill_id WHERE cs.character_id IS NULL)
        OR to_version_id IN (
          SELECT v.id FROM character_skill_versions v
          JOIN character_skills cs ON cs.id = v.character_skill_id WHERE cs.character_id IS NULL)
      SQL
      execute <<~SQL.squish
        DELETE FROM character_skill_versions WHERE character_skill_id IN (
          SELECT id FROM character_skills WHERE character_id IS NULL)
      SQL
      execute "DELETE FROM character_skills WHERE character_id IS NULL"
    end

    change_column_null :character_skills, :character_id, false
    remove_index :character_skills, name: "idx_character_skills_unique_slot"
    add_index :character_skills, %i[character_id kind position], unique: true, name: "idx_character_skills_unique_slot"
  end

  def down
    style_skills = select_value(<<~SQL.squish).to_i
      SELECT count(*) FROM character_skills cs JOIN characters c ON c.id = cs.character_id WHERE c.style_swap = true
    SQL
    if style_skills.positive?
      raise ActiveRecord::IrreversibleMigration, "#{style_skills} skills belong to style rows; granblue_id can't hold both"
    end

    remove_index :character_skills, name: "idx_character_skills_unique_slot"
    add_index :character_skills, %i[character_granblue_id kind position], unique: true,
                                                                         name: "idx_character_skills_unique_slot"
    remove_reference :character_skills, :character, foreign_key: true
  end
end
