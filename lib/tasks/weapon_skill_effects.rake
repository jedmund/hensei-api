# frozen_string_literal: true

namespace :granblue do
  desc "Load/upsert conditional weapon skill effects from data/weapon_skill_effects.json"
  task load_weapon_skill_effects: :environment do
    file = Rails.root.join("data", "weapon_skill_effects.json")
    payload = JSON.parse(File.read(file))
    records = payload.is_a?(Hash) ? payload["effects"] : payload
    puts "Loading #{records.size} weapon skill effects..."

    cols = %w[series value value_unit per_copy_cap total_cap shared_cap_group
              cap_formula count_basis count_cap condition target_instance depends_on
              aura_boostable seraphic_affected stacking applies_to battle_interaction notes]

    created = 0
    updated = 0
    records.each do |r|
      effect = WeaponSkillEffect.find_or_initialize_by(
        modifier: r["modifier"], boost_type: r["boost_type"], scaling_kind: r["scaling_kind"]
      )
      created += 1 if effect.new_record?
      updated += 1 if effect.persisted?
      cols.each do |c|
        next unless r.key?(c)
        effect[c] = r[c]
      end
      # apply schema defaults for omitted columns
      effect.condition ||= {}
      effect.depends_on ||= []
      effect.save!
    end
    puts "Done. created=#{created} updated=#{updated} total=#{WeaponSkillEffect.count}"
  end
end
