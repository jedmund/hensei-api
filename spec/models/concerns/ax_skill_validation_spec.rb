# frozen_string_literal: true

require "rails_helper"

RSpec.describe AxSkillValidation do
  %i[collection_weapon grid_weapon].each do |factory|
    context "on #{factory}" do
      let(:standard_weapon) { create(:weapon, :with_ax) }
      let(:plain_weapon) { create(:weapon) }
      let(:primary) { create(:weapon_stat_modifier, :ax_atk) }
      let(:allowed_secondary) { create(:weapon_stat_modifier, :ax_ca_dmg) }
      let(:wrong_secondary) { create(:weapon_stat_modifier, :ax_hp) }

      def record(factory, weapon, **attrs)
        build(factory, { weapon: weapon }.merge(attrs))
      end

      it "accepts a documented primary/secondary pair and their ranges" do
        item = record(factory, standard_weapon,
                      ax_modifier1: primary, ax_strength1: 3.5,
                      ax_modifier2: allowed_secondary, ax_strength2: 4)

        expect(item).to be_valid
      end

      it "rejects AX rolls on a weapon that cannot have them" do
        item = record(factory, plain_weapon, ax_modifier1: primary, ax_strength1: 3.5)

        expect(item).not_to be_valid
        expect(item.errors[:base]).to include("AX skills are not available for this weapon")
      end

      it "rejects a second AX slot without a first slot" do
        item = record(factory, standard_weapon,
                      ax_modifier2: allowed_secondary, ax_strength2: 4)

        expect(item).not_to be_valid
        expect(item.errors[:ax_modifier2]).to include("requires AX skill 1")
      end

      it "rejects a secondary outside the selected primary's pool" do
        item = record(factory, standard_weapon,
                      ax_modifier1: primary, ax_strength1: 3.5,
                      ax_modifier2: wrong_secondary, ax_strength2: 3)

        expect(item).not_to be_valid
        expect(item.errors[:ax_modifier2]).to include("is not available for ATK")
      end

      it "uses the secondary range when a primary modifier appears in slot two" do
        item = record(factory, standard_weapon,
                      ax_modifier1: primary, ax_strength1: 3.5,
                      ax_modifier2: allowed_secondary, ax_strength2: 8.5)

        expect(item).not_to be_valid
        expect(item.errors[:ax_strength2]).to include("must be between 2.0 and 4.0")
      end

      it "rejects an out-of-range primary" do
        item = record(factory, standard_weapon, ax_modifier1: primary, ax_strength1: 4)

        expect(item).not_to be_valid
        expect(item.errors[:ax_strength1]).to include("must be between 1.0 and 3.5")
      end
    end
  end

  it "uses the Xeno secondary pool" do
    series = WeaponSeries.find_by(slug: "xeno") || create(:weapon_series, :xeno, :with_ax_skills)
    series.update!(augment_type: :ax)
    weapon = create(:weapon, weapon_series: series)
    primary = create(:weapon_stat_modifier, :ax_atk)
    xeno_secondary = create(
      :weapon_stat_modifier,
      slug: "ax_skill_supp", name_en: "Supplemental Skill DMG", stat: "skill_supp",
      ax_group: "extended", base_min: 1, base_max: 5, secondary_min: 1, secondary_max: 5
    )
    item = build(:collection_weapon, weapon: weapon,
                 ax_modifier1: primary, ax_strength1: 3.5,
                 ax_modifier2: xeno_secondary, ax_strength2: 5)

    expect(item).to be_valid
  end

  it "allows one utility roll and rejects a second AX slot" do
    weapon = create(:weapon, :with_ax, ax_type: "utility")
    utility = create(
      :weapon_stat_modifier,
      slug: "ax_exp", name_en: "EXP Gain", stat: "exp", ax_group: "utility",
      base_min: 5, base_max: 10
    )
    secondary = create(:weapon_stat_modifier, :ax_ca_dmg)
    item = build(:collection_weapon, weapon: weapon,
                 ax_modifier1: utility, ax_strength1: 10,
                 ax_modifier2: secondary, ax_strength2: 4)

    expect(item).not_to be_valid
    expect(item.errors[:ax_modifier2]).to include("is not available with a utility AX skill")
  end
end
