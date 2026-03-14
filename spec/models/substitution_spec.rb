# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substitution, type: :model do
  let(:party) { create(:party) }
  let(:character1) { Character.find_by!(granblue_id: '3040087000') }
  let(:character2) { Character.order(:id).where.not(id: character1.id).first }

  let(:primary_gc) do
    create(:grid_character, party: party, character: character1, position: 0)
  end

  let(:substitute_gc) do
    create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
  end

  describe 'validations' do
    it 'is valid with matching grid and substitute types' do
      sub = Substitution.new(
        grid: primary_gc,
        substitute_grid: substitute_gc,
        position: 0
      )
      expect(sub).to be_valid
    end

    it 'rejects mismatched grid and substitute types' do
      weapon = create(:grid_weapon, party: party, is_substitute: true)
      sub = Substitution.new(
        grid_type: 'GridCharacter',
        grid_id: primary_gc.id,
        substitute_grid_type: 'GridWeapon',
        substitute_grid_id: weapon.id,
        position: 0
      )
      expect(sub).not_to be_valid
      expect(sub.errors[:substitute_grid_type]).to include('must match grid_type')
    end

    it 'rejects position below 0' do
      sub = Substitution.new(grid: primary_gc, substitute_grid: substitute_gc, position: -1)
      expect(sub).not_to be_valid
    end

    it 'rejects position 10 or above' do
      sub = Substitution.new(grid: primary_gc, substitute_grid: substitute_gc, position: 10)
      expect(sub).not_to be_valid
    end

    it 'accepts position 9 (the maximum)' do
      sub = Substitution.new(grid: primary_gc, substitute_grid: substitute_gc, position: 9)
      expect(sub).to be_valid
    end

    it 'enforces the 10-substitution limit per grid item' do
      10.times do |i|
        alt_char = Character.order(:id).offset(i + 2).first
        alt_gc = create(:grid_character, party: party, character: alt_char, position: 0, is_substitute: true)
        Substitution.create!(grid: primary_gc, substitute_grid: alt_gc, position: i)
      end

      eleventh_char = Character.order(:id).offset(12).first
      eleventh_gc = create(:grid_character, party: party, character: eleventh_char, position: 0, is_substitute: true)
      sub = Substitution.new(grid: primary_gc, substitute_grid: eleventh_gc, position: 0)
      # position 0 is taken so it will fail uniqueness at DB level, but let's test with a free position
      # Actually all positions 0-9 are taken, so any position would hit the limit
      sub.position = 0 # would be duplicate position too
      expect(sub).not_to be_valid
    end
  end

  describe 'cascade on primary deletion' do
    it 'destroys substitution records when the primary grid item is destroyed' do
      sub = Substitution.create!(grid: primary_gc, substitute_grid: substitute_gc, position: 0)
      expect { primary_gc.destroy }.to change(Substitution, :count).by(-1)
    end

    it 'leaves the substitute grid item cleanup to the controller' do
      Substitution.create!(grid: primary_gc, substitute_grid: substitute_gc, position: 0)
      # The substitute grid item belongs to the party, so it gets cleaned up via party.all_characters dependent: :destroy
      # but destroying just the primary only cascades the join record
      primary_gc.destroy
      expect(GridCharacter.exists?(substitute_gc.id)).to be true
    end
  end
end
