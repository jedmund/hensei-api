# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'validations' do
    it 'is valid with name_en and slot_type' do
      role = Role.new(name_en: 'Buffer', slot_type: 'Character')
      expect(role).to be_valid
    end

    it 'is invalid without name_en' do
      role = Role.new(slot_type: 'Character')
      expect(role).not_to be_valid
    end

    it 'is invalid with bad slot_type' do
      role = Role.new(name_en: 'Buffer', slot_type: 'Invalid')
      expect(role).not_to be_valid
    end
  end

  describe '.for_slot' do
    it 'filters by slot_type' do
      char_role = create(:role, slot_type: 'Character')
      weapon_role = create(:role, :weapon)

      results = Role.for_slot('Character')
      expect(results).to include(char_role)
      expect(results).not_to include(weapon_role)
    end
  end
end
