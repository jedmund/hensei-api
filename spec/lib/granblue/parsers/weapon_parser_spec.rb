# frozen_string_literal: true

require 'rails_helper'

# Uses the Hrunting fixture (granblue_id 1040022900) — an Illustrious weapon
# with 4 skill slots whose tiers span base/FLB and Transcendence stages.
RSpec.describe Granblue::Parsers::WeaponParser do
  let(:fixture) { Rails.root.join('spec/fixtures/wiki/hrunting.txt').read }
  let(:weapon) { create(:weapon, granblue_id: '1040022900') }
  let(:parser) { described_class.new(granblue_id: weapon.granblue_id) }
  # Pure path: parse the inline page template, no network template fetch.
  let(:hash) { parser.send(:parse_string, fixture) }
  let(:skills) { parser.send(:extract_weapon_skills, hash) }

  describe '#tier_for' do
    it 'maps unlock level to uncap/transcendence tier' do
      expect(parser.send(:tier_for, nil)).to eq(min_uncap: 3, transcendence_stage: 0)
      expect(parser.send(:tier_for, 100)).to eq(min_uncap: 3, transcendence_stage: 0)
      expect(parser.send(:tier_for, 150)).to eq(min_uncap: 4, transcendence_stage: 0)
      expect(parser.send(:tier_for, 200)).to eq(min_uncap: 5, transcendence_stage: 0)
      expect(parser.send(:tier_for, 210)).to eq(min_uncap: 5, transcendence_stage: 1)
      expect(parser.send(:tier_for, 230)).to eq(min_uncap: 5, transcendence_stage: 3)
      expect(parser.send(:tier_for, 250)).to eq(min_uncap: 5, transcendence_stage: 5)
    end
  end

  describe '#extract_weapon_skills' do
    it 'extracts all 4 slots' do
      expect(skills.map { |s| s[:position] }).to eq([0, 1, 2, 3])
    end

    it 'slot 0 evolves base → T1@210 → T4@240 (ordered by level, not suffix)' do
      versions = skills[0][:versions]
      expect(versions.map { |v| v[:ordinal] }).to eq([0, 1, 2])
      expect(versions.map { |v| v[:unlock_level] }).to eq([nil, 210, 240])
      expect(versions.map { |v| [v[:min_uncap], v[:transcendence_stage]] }).to eq([[3, 0], [5, 1], [5, 4]])
      expect(versions.map { |v| v[:name_en] }).to eq(
        ['Savage Mythology', 'Savage Mythology II', 'Savage Mythology III']
      )
    end

    it 'slot 1 has base + T2@220' do
      versions = skills[1][:versions]
      expect(versions.map { |v| v[:unlock_level] }).to eq([nil, 220])
      expect(versions.map { |v| v[:transcendence_stage] }).to eq([0, 2])
    end

    it 'slot 2 is a single FLB-tier scaling grid skill (Terra\'s Enmity)' do
      versions = skills[2][:versions]
      expect(versions.size).to eq(1)
      expect(versions[0]).to include(unlock_level: 150, min_uncap: 4, transcendence_stage: 0,
                                     modifier: 'Enmity', series: 'normal', main_hand_only: false)
    end

    it 'slot 3 has T3@230 + T5@250' do
      versions = skills[3][:versions]
      expect(versions.map { |v| v[:unlock_level] }).to eq([230, 250])
      expect(versions.map { |v| v[:transcendence_stage] }).to eq([3, 5])
    end

    it 'derives main_hand_only / mc_only from the description text' do
      expect(skills[0][:versions].map { |v| v[:main_hand_only] }).to all(be true)
      expect(skills[0][:versions].map { |v| v[:mc_only] }).to all(be true)
      # Abandoned Role is "When main weapon" but not "(MC only)"
      expect(skills[1][:versions].map { |v| v[:main_hand_only] }).to all(be true)
      expect(skills[1][:versions].map { |v| v[:mc_only] }).to all(be false)
    end

    it 'never collects the charge attack as a weapon skill' do
      names = skills.flat_map { |s| s[:versions] }.map { |v| v[:name_en] }
      expect(names).not_to include('Here at Last', 'Demise at Last')
    end
  end

  describe '#persist_skills' do
    before do
      WeaponSkillDatum.find_or_create_by!(modifier: 'Enmity', boost_type: 'atk', series: 'normal', size: 'big') do |datum|
        datum.formula_type = 'enmity'
        datum.sl1 = 1.0
        datum.sl10 = 10.0
        datum.sl15 = 15.0
      end

      parser.send(:persist_skills, skills)
    end

    it 'creates one slot per occupied position and ordered version tiers' do
      weapon.reload
      expect(weapon.weapon_skills.count).to eq(4)
      expect(weapon.weapon_skill_versions.count).to eq(8)
    end

    it 'stores the scaling flag: standard modifier scales, unique skill does not' do
      weapon.reload
      enmity = weapon.weapon_skill_versions.find_by(skill_modifier: 'Enmity')
      expect(enmity.scales_with_skill_level).to be true
      expect(enmity.name_en).to eq("Terra's Enmity")

      savage = weapon.weapon_skills.find_by(position: 0).weapon_skill_versions.order(:ordinal).first
      expect(savage.skill_modifier).to be_nil
      expect(savage.scales_with_skill_level).to be false
    end

    it 'does not mark recognized modifiers as scaling when no lookup data exists' do
      WeaponSkillDatum.where(modifier: 'Abandon').delete_all
      skill_data = [{
        position: 0,
        versions: [{
          ordinal: 0,
          name_en: 'Abandon Test',
          description_en: 'A known modifier without seeded skill data',
          icon: nil,
          unlock_level: nil,
          min_uncap: 3,
          transcendence_stage: 0,
          main_hand_only: false,
          mc_only: false,
          modifier: 'Abandon',
          series: 'normal',
          size: 'big'
        }]
      }]

      parser.send(:persist_skills, skill_data)

      version = weapon.reload.weapon_skill_versions.find_by(skill_modifier: 'Abandon')
      expect(version.scales_with_skill_level).to be false
      expect(version.weapon_skill_data).to be_empty
    end

    it 'is idempotent across re-parses' do
      parser.send(:persist_skills, skills)
      weapon.reload
      expect(weapon.weapon_skills.count).to eq(4)
      expect(weapon.weapon_skill_versions.count).to eq(8)
    end

    it 'prunes positions and version tiers removed from the wiki data' do
      reduced = [skills[0].merge(versions: [skills[0][:versions].first])]
      parser.send(:persist_skills, reduced)
      weapon.reload
      expect(weapon.weapon_skills.count).to eq(1)
      expect(weapon.weapon_skill_versions.count).to eq(1)
    end
  end
end
