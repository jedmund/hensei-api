# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'associations' do
  end

  describe 'validations' do
    it { should validate_presence_of(:name_en) }
    it { should validate_presence_of(:slot_type) }
    it { should validate_inclusion_of(:slot_type).in_array(%w[Character Weapon Summon]) }
  end

  describe '.for_slot' do
    let!(:char_role) { create(:role, name_en: 'Buffer', slot_type: 'Character') }
    let!(:weapon_role) { create(:role, name_en: 'Stat stick', slot_type: 'Weapon') }
    let!(:summon_role) { create(:role, name_en: 'Main aura', slot_type: 'Summon') }

    it 'returns only roles matching the given slot type' do
      results = Role.for_slot('Character')
      expect(results).to include(char_role)
      expect(results).not_to include(weapon_role, summon_role)
    end

    it 'returns an empty relation for an unknown slot type' do
      expect(Role.for_slot('Unknown')).to be_empty
    end
  end
end
