# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridCharacterRole, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      role = build(:grid_character_role, name_en: 'Attacker')
      expect(role).to be_valid
    end

    it 'requires name_en' do
      role = build(:grid_character_role, name_en: nil)
      expect(role).not_to be_valid
    end
  end

  describe 'associations' do
    it 'has many characters through assignments' do
      role = create(:grid_character_role)
      party = create(:party)
      gc = create(:grid_character, party: party)
      gc.grid_character_roles << role

      expect(role.grid_characters).to include(gc)
    end

    it 'destroys assignments when destroyed' do
      role = create(:grid_character_role)
      party = create(:party)
      gc = create(:grid_character, party: party)
      gc.grid_character_roles << role

      expect { role.destroy }.to change(GridCharacterRoleAssignment, :count).by(-1)
    end
  end
end
