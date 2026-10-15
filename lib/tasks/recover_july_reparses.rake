# frozen_string_literal: true

# One-off follow-up to the July recovery data migrations: these weapons need their
# wiki pages refetched, which a migration can't do. Run once after deploying them.
namespace :granblue do
  desc "Refetch + reparse Ereshkigal and Rhomphaia so their upgrade tiers exist, then " \
       "apply Rhomphaia's overrides. dry_run=true rolls everything back."
  task recover_july_reparses: :environment do
    dry_run = ENV["dry_run"] == "true"
    weapons = Weapon.where(name_en: %w[Ereshkigal Rhomphaia]).to_a

    ActiveRecord::Base.transaction do
      weapons.each do |weapon|
        # a savepoint per weapon, so one failure doesn't abort the whole transaction
        ActiveRecord::Base.transaction(requires_new: true) do
          Granblue::EntityReparser.new(weapon, refetch: true).reparse
        end
        puts "reparsed #{weapon.name_en}"
      rescue StandardError => e
        puts "FAILED #{weapon.name_en}: #{e.class}: #{e.message}"
      end

      # 'Cyclonic Strike' is not the Strike family, nor 'Electrifying Onslaught' the
      # Onslaught family; Cyclonic Strike II's DEF ignore tooltip isn't a panel line
      # (SPhnLB).
      rhomphaia = WeaponSkillVersion.joins(:skill, :weapon_skill)
                                    .where(weapon_skills: { weapon_granblue_id: Weapon.find_by!(name_en: "Rhomphaia").granblue_id })
      rhomphaia.where("skills.name_en LIKE 'Cyclonic Strike%' OR skills.name_en LIKE 'Electrifying Onslaught%'")
               .find_each { |v| v.update!(modifier_override: "none", overrides_edited_at: Time.current) }
      rhomphaia.where(skills: { name_en: "Cyclonic Strike II" }).find_each do |v|
        v.update!(suppressed_boosts: Array(v.suppressed_boosts) | ["def_ignore"], overrides_edited_at: Time.current)
        WeaponSkillEffect.where(weapon_skill_version_id: v.id, boost_type: "def_ignore", manually_edited_at: nil).delete_all
      end
      raise ActiveRecord::Rollback if dry_run
    end
    puts dry_run ? "dry run — rolled back" : "done"
  end
end
