# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkill, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:weapon) }
    it { is_expected.to have_many(:weapon_skill_versions).dependent(:destroy) }
  end

  describe 'validations' do
    let(:weapon) { create(:weapon) }
    subject { build(:weapon_skill, weapon: weapon, position: 0) }

    it { is_expected.to validate_presence_of(:weapon_granblue_id) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    context 'position uniqueness' do
      it 'validates uniqueness scoped to weapon' do
        create(:weapon_skill, weapon: weapon, position: 0)
        duplicate = build(:weapon_skill, weapon: weapon, position: 0)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).to include('has already been taken')
      end

      it 'allows the same position on different weapons' do
        other_weapon = create(:weapon)
        create(:weapon_skill, weapon: weapon, position: 0)
        other = build(:weapon_skill, weapon: other_weapon, position: 0)
        expect(other).to be_valid
      end
    end
  end

  describe 'versions' do
    it 'returns versions ordered by ordinal' do
      ws = create(:weapon_skill, weapon: create(:weapon), position: 0)
      create(:weapon_skill_version, weapon_skill: ws, ordinal: 2)
      create(:weapon_skill_version, weapon_skill: ws, ordinal: 0)
      create(:weapon_skill_version, weapon_skill: ws, ordinal: 1)
      expect(ws.weapon_skill_versions.pluck(:ordinal)).to eq([0, 1, 2])
    end

    it 'destroys versions when the slot is destroyed' do
      ws = create(:weapon_skill, weapon: create(:weapon), position: 0)
      create(:weapon_skill_version, weapon_skill: ws, ordinal: 0)
      expect { ws.destroy }.to change(WeaponSkillVersion, :count).by(-1)
    end
  end
end
