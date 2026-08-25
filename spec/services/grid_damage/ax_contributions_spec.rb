# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::AxContributions do
  let(:party) { create(:party) }

  it "emits the documented Skill DMG Cap secondary on its AX panel key" do
    primary = create(:weapon_stat_modifier, :ax_atk)
    skill_cap = create(
      :weapon_stat_modifier,
      slug: "ax_skill_cap", name_en: "Skill DMG Cap", stat: "skill_cap",
      ax_group: "secondary", base_min: 1, base_max: 2, secondary_min: 1, secondary_max: 2
    )
    weapon = create(:weapon, :with_ax)
    create(:grid_weapon, party: party, weapon: weapon, position: 0,
                         ax_modifier1: primary, ax_strength1: 3.5,
                         ax_modifier2: skill_cap, ax_strength2: 2)

    contributions = described_class.for_party(party)

    expect(contributions.find { |row| row.boost_type == "skill_cap_ax" }).to have_attributes(value: 2.0)
    expect(GridDamage::PanelPresenter::LINES).to include(
      ["skill_cap_ax", nil, "Skill DMG Cap (AX)", "ax-skill-dmg-cap", "ax"]
    )
  end

  it "caps utility AX totals across the grid" do
    exp = create(:weapon_stat_modifier, slug: "ax_exp", name_en: "EXP Gain", stat: "exp",
                                         ax_group: "utility", base_min: 5, base_max: 10)
    rupie = create(:weapon_stat_modifier, slug: "ax_rupie", name_en: "Rupie Gain", stat: "rupie",
                                           ax_group: "utility", base_min: 10, base_max: 20)
    4.times do |position|
      create(:grid_weapon, party: party, weapon: create(:weapon, :with_ax, ax_type: "utility"), position: position,
                           ax_modifier1: exp, ax_strength1: 10)
    end
    3.times do |offset|
      create(:grid_weapon, party: party, weapon: create(:weapon, :with_ax, ax_type: "utility"), position: offset + 4,
                           ax_modifier1: rupie, ax_strength1: 20)
    end

    result = GridDamage::Calculator.boost_list(party)

    expect(result["exp_ax"]).to have_attributes(total: 30.0, raw: 40.0, capped: true)
    expect(result["rupie_ax"]).to have_attributes(total: 50.0, raw: 60.0, capped: true)
  end
end
