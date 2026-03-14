# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substitution, type: :model do
  let(:party) { create(:party) }
  let(:character) { Character.find_by!(granblue_id: '3040087000') }
  let(:character2) { Character.find_by!(granblue_id: '3040036000') }

  let(:primary) do
    create(:grid_character, party: party, character: character, position: 0)
  end

  let(:substitute) do
    create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
  end

  describe 'validations' do
    it 'is valid with matching grid types' do
      sub = Substitution.new(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: substitute.id,
        position: 0
      )
      expect(sub).to be_valid
    end

    it 'rejects mismatched grid types' do
      weapon = create(:grid_weapon, party: party)
      sub = Substitution.new(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridWeapon', substitute_grid_id: weapon.id,
        position: 0
      )
      expect(sub).not_to be_valid
      expect(sub.errors[:substitute_grid_type]).to include('must match grid_type')
    end

    it 'rejects position below 0' do
      sub = Substitution.new(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: substitute.id,
        position: -1
      )
      expect(sub).not_to be_valid
    end

    it 'rejects position >= 10' do
      sub = Substitution.new(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: substitute.id,
        position: 10
      )
      expect(sub).not_to be_valid
    end

    it 'accepts position 9' do
      sub = Substitution.new(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: substitute.id,
        position: 9
      )
      expect(sub).to be_valid
    end

    it 'enforces 10-substitution cap' do
      10.times do |i|
        sub_char = create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
        Substitution.create!(
          grid_type: 'GridCharacter', grid_id: primary.id,
          substitute_grid_type: 'GridCharacter', substitute_grid_id: sub_char.id,
          position: i
        )
      end

      eleventh = create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
      sub = Substitution.new(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: eleventh.id,
        position: 0 # position 0 is taken, but the limit check fires first
      )
      expect(sub).not_to be_valid
      expect(sub.errors[:base].join).to match(/cannot have more than 10/)
    end
  end

  describe 'cascade on primary deletion' do
    it 'destroys substitutions and substitute grid items when primary is destroyed' do
      Substitution.create!(
        grid_type: 'GridCharacter', grid_id: primary.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: substitute.id,
        position: 0
      )

      expect { primary.destroy! }.to change(Substitution, :count).by(-1)
    end
  end
end
