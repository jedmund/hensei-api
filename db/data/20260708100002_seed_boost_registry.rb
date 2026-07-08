# frozen_string_literal: true

# Seeds the boost-type registry from the code constants that have carried the
# nine goldens: panel lines, display caps, amplifiability, hidden keys, and the
# per-series summon-boost flag. From here the DB rows are the truth; the
# constants remain only as bare-database defaults.
class SeedBoostRegistry < ActiveRecord::Migration[8.0]
  NON_SUMMON_BOOSTED = %w[bahamut celestial ultima destroyer].freeze

  def up
    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), i|
      line = PanelLine.find_or_initialize_by(boost_type: key, series: series)
      line.update!(label_en: label, slug: slug, group_name: group, position: i)
    end

    GridDamage::Calculator::RATE_CAPS.each do |key, cap|
      registry_row(key).update!(display_cap: cap)
    end

    GridDamage::Calculator::NON_AMPLIFIED_BOOSTS.each do |key|
      registry_row(key).update!(amplifiable: false)
    end

    GridDamage::PanelPresenter::HIDDEN_KEYS.each do |key|
      registry_row(key).update!(hidden: true)
    end

    WeaponSeries.find_each do |series|
      series.update!(summon_boosted: NON_SUMMON_BOOSTED.exclude?(series.slug))
    end
  end

  def registry_row(key)
    WeaponSkillBoostType.find_or_create_by!(key: key) do |r|
      r.name_en = key.tr("_", " ")
      r.category = "utility"
    end
  end

  def down
    PanelLine.delete_all
    WeaponSkillBoostType.update_all(display_cap: nil, amplifiable: nil, hidden: false)
    WeaponSeries.update_all(summon_boosted: nil)
  end
end
