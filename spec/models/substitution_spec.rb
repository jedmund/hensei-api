# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substitution, type: :model do
  let(:party) { create(:party) }

  describe 'validations' do
    it 'requires position between 0 and 9' do
      grid_weapon = create(:grid_weapon, party: party)
      sub_weapon = create(:grid_weapon, party: party, is_substitute: true)

      sub = build(:substitution,
                  grid: grid_weapon,
                  substitute_grid: sub_weapon,
                  position: 10)
      expect(sub).not_to be_valid

      sub.position = -1
      expect(sub).not_to be_valid

      sub.position = 0
      expect(sub).to be_valid
    end

    it 'requires grid types to match' do
      grid_weapon = create(:grid_weapon, party: party)
      grid_character = create(:grid_character, party: party, is_substitute: true)

      sub = build(:substitution,
                  grid: grid_weapon,
                  substitute_grid: grid_character,
                  position: 0)
      expect(sub).not_to be_valid
      expect(sub.errors[:substitute_grid_type]).to include('must match grid type')
    end

    it 'enforces 10-per-slot cap' do
      grid_weapon = create(:grid_weapon, party: party)

      10.times do |i|
        sub_weapon = create(:grid_weapon, party: party, is_substitute: true)
        create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: i)
      end

      extra_weapon = create(:grid_weapon, party: party, is_substitute: true)
      sub = build(:substitution, grid: grid_weapon, substitute_grid: extra_weapon, position: 10)
      expect(sub).not_to be_valid
    end
  end

  describe 'cascade delete' do
    it 'destroys substitutions when grid item is destroyed' do
      grid_weapon = create(:grid_weapon, party: party)
      sub_weapon = create(:grid_weapon, party: party, is_substitute: true)
      create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: 0)

      expect { grid_weapon.destroy }.to change(Substitution, :count).by(-1)
    end
  end
end
