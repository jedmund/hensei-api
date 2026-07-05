# frozen_string_literal: true

namespace :granblue do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  KEY_SKILL_COLS = %w[modifier boost_type series scaling_kind value value_unit condition
                      frame_rule stacking applies_to total_cap per_copy_cap count_basis count_cap].freeze
  # rubocop:enable Lint/ConstantDefinitionInBlock

  desc "Sync key-granted weapon skills (Dark Opus pendulum/teluma etc.) from data/weapon_key_skills.json into weapon_skill_effects"
  task load_weapon_key_skills: :environment do
    records = JSON.parse(File.read(Rails.root.join("data", "weapon_key_skills.json")))
    keys = records.to_set { |r| r.values_at("key_slug", "modifier", "boost_type", "scaling_kind") }

    records.each do |r|
      e = WeaponSkillEffect.find_or_initialize_by(
        key_slug: r["key_slug"], modifier: r["modifier"],
        boost_type: r["boost_type"], scaling_kind: r["scaling_kind"]
      )
      KEY_SKILL_COLS.each { |c| e[c] = r[c] if r.key?(c) }
      e.condition = r["condition"] || {} # condition is NOT NULL (default {})
      e.save!
    end
    pruned = WeaponSkillEffect.where.not(key_slug: nil).reject do |e|
      keys.include?([e.key_slug, e.modifier, e.boost_type, e.scaling_kind])
    end
    pruned.each(&:destroy)
    puts "Loaded #{records.size} key-skill effects; pruned #{pruned.size}; total key effects #{WeaponSkillEffect.where.not(key_slug: nil).count}."
  end
end
