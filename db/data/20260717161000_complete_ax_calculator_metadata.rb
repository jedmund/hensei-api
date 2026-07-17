# frozen_string_literal: true

# Completes the wiki-backed AX registry: secondary pools/ranges, the omitted
# Skill DMG Cap roll, ordered panel line, and aggregate EXP/Rupie caps.
class CompleteAxCalculatorMetadata < ActiveRecord::Migration[8.0]
  ADDED_PANEL_KEYS = %w[skill_hit skill_cap_ax].freeze

  def up
    WeaponStatModifier.reset_column_information
    PanelLine.reset_column_information
    WeaponSkillBoostType.reset_column_information

    skill_cap = WeaponStatModifier.find_or_initialize_by(slug: "ax_skill_cap")
    skill_cap.update!(
      name_en: "Skill DMG Cap", name_jp: "アビダメ上限", category: "ax",
      stat: "skill_cap", polarity: 1, suffix: "%", ax_group: "secondary",
      base_min: 1, base_max: 2, secondary_min: 1, secondary_max: 2
    )

    WeaponStatModifier::AX_SECONDARY_RANGES.each do |slug, (minimum, maximum)|
      WeaponStatModifier.find_by(slug: slug)&.update!(secondary_min: minimum, secondary_max: maximum)
    end
    WeaponStatModifier::AX_SECONDARY_POOLS.each do |slug, pools|
      WeaponStatModifier.find_by(slug: slug)&.update!(ax_secondaries: pools)
    end

    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end

    upsert_boost_type("skill_hit", "Skill Hit", "offensive")
    upsert_boost_type("exp_ax", "EXP Gain", "utility").update!(display_cap: 30)
    upsert_boost_type("rupie_ax", "Rupie Gain", "utility").update!(display_cap: 50)
  end

  def down
    PanelLine.where(boost_type: ADDED_PANEL_KEYS).delete_all
    GridDamage::PanelPresenter::LINES.reject { |line| ADDED_PANEL_KEYS.include?(line.first) }
                                     .each_with_index do |(key, series, _label, _slug, _group), position|
      PanelLine.find_by(boost_type: key, series: series)&.update!(position: position)
    end
    WeaponSkillBoostType.where(key: "skill_hit").delete_all
    WeaponSkillBoostType.where(key: %w[exp_ax rupie_ax]).update_all(display_cap: nil)
    WeaponStatModifier.where(slug: "ax_skill_cap").update_all(base_min: nil, base_max: nil)
  end

  private

  def upsert_boost_type(key, name, category)
    row = WeaponSkillBoostType.find_or_initialize_by(key: key)
    row.assign_attributes(name_en: name, category: category)
    row.save!
    row
  end
end
