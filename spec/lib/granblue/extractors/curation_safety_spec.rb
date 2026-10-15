# frozen_string_literal: true

require 'rails_helper'

# Extractor paths that used to destroy or bypass curation.
RSpec.describe 'Weapon-skill extractor curation safety' do
  describe Granblue::Extractors::ExpandedWeaponSkillImporter, '.cleanup_garbled' do
    let(:weapon) { create(:weapon) }
    let(:slot) { create(:weapon_skill, weapon: weapon, position: 0) }
    let(:garbled_skill) { create(:skill, name_en: 'Sephira Maxi-{{WeaponElement|water}}') }

    def cleanup(stats = Hash.new(0))
      described_class.send(:cleanup_garbled, weapon, stats)
      stats
    end

    it 'destroys a garbled version that carries no curation' do
      version = create(:weapon_skill_version, weapon_skill: slot, skill: garbled_skill)
      create(:weapon_skill_datum, weapon_skill_version_id: version.id)

      stats = cleanup

      expect(WeaponSkillVersion.exists?(version.id)).to be(false)
      expect(WeaponSkillDatum.where(weapon_skill_version_id: version.id)).to be_empty
      expect(stats[:garbled_removed]).to eq(1)
    end

    it 'keeps a garbled version with manually-edited rows, deleting only its generated rows' do
      version = create(:weapon_skill_version, weapon_skill: slot, skill: garbled_skill)
      generated = create(:weapon_skill_datum, weapon_skill_version_id: version.id, boost_type: 'atk')
      curated = WeaponSkillEffect.create!(weapon_skill_version_id: version.id, modifier: 'Sephira Maxi-Water',
                                          boost_type: 'dmg_cap', scaling_kind: 'static', value: 5.0,
                                          stacking: 'additive', manually_edited_at: Time.current)

      stats = cleanup

      expect(WeaponSkillVersion.exists?(version.id)).to be(true)
      expect(WeaponSkillDatum.exists?(generated.id)).to be(false)
      expect(WeaponSkillEffect.exists?(curated.id)).to be(true)
      expect(stats[:garbled_kept]).to eq(1)
      expect(stats[:garbled_removed]).to eq(0)
    end

    it 'keeps a garbled version with classification overrides' do
      version = create(:weapon_skill_version, weapon_skill: slot, skill: garbled_skill,
                                              series_override: 'omega', overrides_edited_at: Time.current)

      expect(cleanup[:garbled_kept]).to eq(1)
      expect(WeaponSkillVersion.exists?(version.id)).to be(true)
      expect(WeaponSkill.exists?(slot.id)).to be(true)
    end
  end

  describe Granblue::Extractors::WeaponSkillDescriptionExtractor, '.family_curve' do
    let(:clause) { { boost_type: 'atk', size: 'big', series: nil } }

    before do
      create(:weapon_skill_datum, modifier: 'Might', series: 'normal', size: 'big', sl15: 15.0)
      create(:weapon_skill_datum, modifier: 'Might', series: 'omega', size: 'big', sl15: 20.0)
    end

    def curve(version)
      described_class.send(:family_curve, version, clause)
    end

    it 'never picks up a family curve when the modifier is overridden to "none"' do
      version = build(:weapon_skill_version, skill_modifier: 'Might', skill_series: 'normal',
                                             modifier_override: 'none')

      expect(curve(version)).to be_nil
    end

    it 'resolves the family through the overrides' do
      version = build(:weapon_skill_version, skill_modifier: nil, skill_series: 'normal',
                                             modifier_override: 'Might', series_override: 'omega')

      expect(curve(version).sl15.to_f).to eq(20.0)
    end
  end
end
