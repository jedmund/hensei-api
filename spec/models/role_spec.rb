# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      role = build(:role, name_en: 'Attacker', slot_type: 'Character')
      expect(role).to be_valid
    end

    it 'requires name_en' do
      role = build(:role, name_en: nil)
      expect(role).not_to be_valid
    end

    it 'requires slot_type' do
      role = build(:role, slot_type: nil)
      expect(role).not_to be_valid
    end

    it 'rejects invalid slot_type' do
      role = build(:role, slot_type: 'Invalid')
      expect(role).not_to be_valid
    end

    it 'accepts Character, Weapon, Summon' do
      %w[Character Weapon Summon].each do |type|
        role = build(:role, slot_type: type)
        expect(role).to be_valid
      end
    end
  end

  describe '.for_slot' do
    it 'filters by slot_type' do
      create(:role, slot_type: 'Character')
      create(:role, :weapon)
      expect(Role.for_slot('Character').count).to eq(1)
    end
  end
end
