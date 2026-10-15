# frozen_string_literal: true

# Bahamut Coda weapons unlock their third skill (Vita, Incursio or Rapidus) at level 200,
# which needs 5★ (gbf.wiki Bahamut_Weapons, template s3_lvl=200). The imported versions
# had no unlock level and a 3★ minimum, so a 4★ Coda counted them too.
class GateBahamutCodaLevelTwoHundredSkills < ActiveRecord::Migration[8.0]
  SKILL_PREFIXES = %w[Vita Incursio Rapidus].freeze

  def up
    WeaponSkillVersion.reset_column_information
    series = WeaponSeries.find_by(slug: "bahamut") or return

    names = SKILL_PREFIXES.map { |prefix| "#{prefix} %" }
    WeaponSkillVersion.joins(:skill, weapon_skill: :weapon)
                      .where(weapons: { weapon_series_id: series.id })
                      .where("skills.name_en LIKE ANY (ARRAY[?])", names)
                      .update_all(unlock_level: 200, min_uncap: 5)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the previous gates were missing, not chosen"
  end
end
