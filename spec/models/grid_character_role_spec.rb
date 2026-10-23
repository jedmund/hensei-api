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

  describe 'attributes' do
    it 'round-trips name_jp' do
      role = create(:grid_character_role, name_en: 'Attacker', name_jp: 'アタッカー')
      expect(role.reload.name_jp).to eq('アタッカー')
    end

    it 'persists sort_order when explicitly set' do
      role = create(:grid_character_role, sort_order: 7)
      expect(role.reload.sort_order).to eq(7)
    end

    it 'leaves sort_order nil when not assigned at the model level' do
      # Controller is responsible for defaulting via next_sort_order; the model
      # itself does not default sort_order. Lock that contract.
      role = GridCharacterRole.create!(name_en: 'Sortless', name_jp: nil, sort_order: nil)
      expect(role.sort_order).to be_nil
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
