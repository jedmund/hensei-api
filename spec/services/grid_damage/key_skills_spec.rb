# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::KeySkills do
  let(:party) { create(:party) }

  def compatible_key(series, **attrs)
    key = WeaponKey.find_by(slug: attrs.fetch(:slug)) || create(:weapon_key, **attrs)
    key.update!(slot: attrs.fetch(:slot))
    key.weapon_series << series unless key.weapon_series.include?(series)
    key
  end

  it "evaluates an Ultima key curve only for a matching weapon specialty" do
    series = WeaponSeries.find_by!(slug: "ultima")
    series.update!(has_weapon_keys: true, summon_boosted: false)
    key = compatible_key(series, slug: "gauph-courage", slot: 0)
    weapon = create(:weapon, :transcendable, weapon_series: series, proficiency: 1)
    create(:grid_weapon, party: party, weapon: weapon, position: 0, uncap_level: 5,
                         skill_level: 15, weapon_key1: key)
    WeaponSkillEffect.where(key_slug: key.slug).delete_all
    WeaponSkillEffect.create!(
      key_slug: key.slug, modifier: "Gauph Key of Courage", boost_type: "critical",
      series: "ex", scaling_kind: "weapon_skill_curve", value_unit: "percent",
      condition: {
        "type" => "weapon_specialty",
        "curve" => { "formula_type" => "flat", "sl10" => 15, "sl15" => 17.5, "sl20" => 20 }
      },
      stacking: "additive", applies_to: "all_allies"
    )

    matched = described_class.contributions(party, composition: { mc_specialties: ["sabre"] })
    unmatched = described_class.contributions(party, composition: { mc_specialties: ["staff"] })

    expect(matched.sole).to have_attributes(boost_type: "critical", series: "ex", value: 17.5,
                                            amplifiable: false)
    expect(unmatched).to be_empty
  end

  it "uses element-specific reduction labels and the selected Omega Teluma frame" do
    series = WeaponSeries.find_by!(slug: "draconic")
    series.update!(has_weapon_keys: true)
    reduction_key = compatible_key(series, slug: "teluma-aureole", slot: 0)
    omega_key = compatible_key(series, slug: "teluma-omega", slot: 1)
    weapon = create(:weapon, :transcendable, weapon_series: series)
    create(:grid_weapon, party: party, weapon: weapon, position: 0, uncap_level: 5,
                         skill_level: 20, weapon_key1: reduction_key, weapon_key2: omega_key)
    WeaponSkillEffect.where(key_slug: [reduction_key.slug, omega_key.slug]).delete_all
    WeaponSkillEffect.create!(
      key_slug: reduction_key.slug, modifier: "Aureole Teluma", boost_type: "elem_reduc",
      series: "ex", scaling_kind: "weapon_skill_curve", value_unit: "percent",
      condition: {
        "reduced_element" => "light",
        "curve" => { "formula_type" => "flat", "sl15" => 25, "sl20" => 30 }
      },
      stacking: "additive", applies_to: "all_allies"
    )
    WeaponSkillEffect.create!(
      key_slug: omega_key.slug, modifier: "Omega Teluma", boost_type: "atk",
      series: "ex", scaling_kind: "weapon_skill_curve", value_unit: "percent",
      condition: { "curve" => { "formula_type" => "flat", "sl20" => 20 } },
      stacking: "additive", applies_to: "element_allies", frame_rule: "teluma"
    )

    contributions = described_class.contributions(party, composition: {})

    expect(contributions).to include(have_attributes(boost_type: "light_reduc", value: 30.0))
    expect(contributions).to include(have_attributes(boost_type: "atk", series: "omega", value: 20.0))
  end
end
