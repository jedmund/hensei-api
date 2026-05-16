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

    it 'rejects self-substitution' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sub = build(:substitution, grid: gw, substitute_grid: gw, position: 0)
      expect(sub).not_to be_valid
      expect(sub.errors[:substitute_grid]).to include('cannot reference itself')
    end

    it 'enforces uniqueness of position within a slot' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw1 = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sw2 = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true, position: 1)
      create(:substitution, grid: gw, substitute_grid: sw1, position: 0)

      duplicate = build(:substitution, grid: gw, substitute_grid: sw2, position: 0)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same position for different parent slots' do
      gw1 = create(:grid_weapon, party: party, weapon: weapon)
      gw2 = create(:grid_weapon, party: party, weapon: other_weapon, position: 1)
      sw1 = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      sw2 = create(:grid_weapon, party: party, weapon: weapon, is_substitute: true, position: 1)

      create(:substitution, grid: gw1, substitute_grid: sw1, position: 0)
      expect { create(:substitution, grid: gw2, substitute_grid: sw2, position: 0) }.not_to raise_error
    end
  end

  describe 'cascade delete' do
    it 'destroys substitutions when primary grid item is destroyed' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      create(:substitution, grid: gw, substitute_grid: sw, position: 0)

      expect { gw.destroy }.to change(Substitution, :count).by(-1)
    end

    it 'destroys substitutions when substitute grid item is destroyed' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      create(:substitution, grid: gw, substitute_grid: sw, position: 0)

      expect { sw.destroy }.to change(Substitution, :count).by(-1)
    end

    it 'destroys all substitutions and substitute rows when the party is destroyed' do
      gw = create(:grid_weapon, party: party, weapon: weapon)
      sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      create(:substitution, grid: gw, substitute_grid: sw, position: 0)

      expect { party.destroy }
        .to change(Substitution, :count).by(-1)
        .and change(GridWeapon.where(is_substitute: true), :count).by(-1)
    end
  end
end
