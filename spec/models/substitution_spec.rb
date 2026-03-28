# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substitution, type: :model do
  let(:party) { create(:party) }
  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:other_weapon) { Weapon.find_by!(granblue_id: '1040912100') }

  describe 'validations' do
    it 'is valid at position 0' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = build(:substitution, grid: gw, substitute_grid: sw, position: 0)
      expect(sub).to be_valid
    end

    it 'is valid at position 9 (max)' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = build(:substitution, grid: gw, substitute_grid: sw, position: 9)
      expect(sub).to be_valid
    end

    it 'rejects position 10 (over max)' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = build(:substitution, grid: gw, substitute_grid: sw, position: 10)
      expect(sub).not_to be_valid
      expect(sub.errors[:position]).to be_present
    end

    it 'rejects negative position' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = build(:substitution, grid: gw, substitute_grid: sw, position: -1)
      expect(sub).not_to be_valid
    end

    it 'rejects mismatched grid types (weapon grid + character substitute)' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      gc = create(:grid_character, party: party, is_substitute: true)

      sub = build(:substitution, grid: gw, substitute_grid: gc, position: 0)
      expect(sub).not_to be_valid
      expect(sub.errors[:substitute_grid_type]).to include('must match grid type')
    end

    it 'allows matching grid types' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = build(:substitution, grid: gw, substitute_grid: sw, position: 0)
      expect(sub).to be_valid
    end

    it 'enforces uniqueness of grid + substitute_grid pair' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      create(:substitution, grid: gw, substitute_grid: sw, position: 0)

      duplicate = build(:substitution, grid: gw, substitute_grid: sw, position: 1)
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'enforces 10-per-slot cap' do
      gw = create(:grid_weapon, party: party, weapon: weapon)

      10.times do |i|
        sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
        create(:substitution, grid: gw, substitute_grid: sw, position: i)
      end

      extra = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = build(:substitution, grid: gw, substitute_grid: extra, position: 0)
      expect(sub).not_to be_valid
      expect(sub.errors[:base]).to include('maximum of 10 substitutions per slot')
    end
  end

  describe 'cascade delete' do
    it 'destroys substitutions when primary grid item is destroyed' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      create(:substitution, grid: gw, substitute_grid: sw, position: 0)

      expect { gw.destroy }.to change(Substitution, :count).by(-1)
    end

    it 'does not destroy the substitute grid item when substitution is destroyed' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sub = create(:substitution, grid: gw, substitute_grid: sw, position: 0)

      expect { sub.destroy }.not_to change(GridWeapon, :count)
    end
  end
end
