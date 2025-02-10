# frozen_string_literal: true

require 'rails_helper'

# Define a dummy GridWeaponBlueprint if it is not already defined.
class GridWeaponBlueprint; end unless defined?(GridWeaponBlueprint)

RSpec.describe GridWeapon, type: :model do
  it { is_expected.to belong_to(:weapon) }
  it { is_expected.to belong_to(:party) }
  it { is_expected.to belong_to(:weapon_key1).optional }
  it { is_expected.to belong_to(:weapon_key2).optional }
  it { is_expected.to belong_to(:weapon_key3).optional }
  it { is_expected.to belong_to(:weapon_key4).optional }
  it { is_expected.to belong_to(:awakening).optional }

  # Setup common test objects using FactoryBot.
  let(:party) { create(:party) }
  let(:weapon) { create(:weapon, limit: false, series: 5) } # a non-limited weapon with series 5
  let(:grid_weapon) do
    build(:grid_weapon,
          party: party,
          weapon: weapon,
          position: 0,
          uncap_level: 3,
          transcendence_step: 0)
  end

  describe 'Validations' do
    context 'Presence validations' do
      it 'requires a party' do
        grid_weapon.party = nil
        grid_weapon.validate
        error_message = grid_weapon.errors[:party].join
        expect(error_message).to include('must exist')
      end
    end

    context 'Custom validations' do
      describe '#compatible_with_position' do
        context 'when position is within extra positions [9, 10, 11]' do
          before { grid_weapon.position = 9 }

          context 'and weapon series is NOT in allowed extra series' do
            before { weapon.series = 5 } # Allowed extra series are [11, 16, 17, 28, 29, 32, 34]
            it 'adds an error on :series' do
              grid_weapon.validate
              expect(grid_weapon.errors[:series]).to include('must be compatible with position')
            end
          end

          context 'and weapon series is in allowed extra series' do
            before { weapon.series = 11 }
            it 'is valid with respect to position compatibility' do
              grid_weapon.validate
              expect(grid_weapon.errors[:series]).to be_empty
            end
          end
        end

        context 'when position is not in extra positions' do
          before { grid_weapon.position = 2 }
          it 'does not add an error on :series' do
            grid_weapon.validate
            expect(grid_weapon.errors[:series]).to be_empty
          end
        end
      end

      describe '#no_conflicts' do
        context 'when there is a conflicting grid weapon in the party' do
          before do
            # Create a limited weapon that will trigger conflict checking.
            limited_weapon = create(:weapon, limit: true, series: 7)
            # Create an existing grid weapon in the party using that limited weapon.
            create(:grid_weapon, party: party, weapon: limited_weapon, position: 1)
            # Set up grid_weapon to use the same limited weapon in a different position.
            grid_weapon.weapon = limited_weapon
            grid_weapon.position = 2
          end

          it 'adds an error on :series about conflicts' do
            grid_weapon.validate
            expect(grid_weapon.errors[:series]).to include('must not conflict with existing weapons')
          end
        end

        context 'when there is no conflicting grid weapon' do
          it 'has no conflict errors' do
            grid_weapon.validate
            expect(grid_weapon.errors[:series]).to be_empty
          end
        end
      end
    end
  end

  describe 'Callbacks' do
    context 'before_save :mainhand?' do
      it 'sets mainhand to true if position is -1' do
        grid_weapon.position = -1
        grid_weapon.save!
        expect(grid_weapon.mainhand).to be true
      end

      it 'sets mainhand to false if position is not -1' do
        grid_weapon.position = 0
        grid_weapon.save!
        expect(grid_weapon.mainhand).to be false
      end
    end
  end

  describe '#weapon_keys' do
    it 'returns an array of associated weapon keys, omitting nils' do
      # Create two dummy weapon keys using the factory.
      weapon_key1 = create(:weapon_key)
      weapon_key2 = create(:weapon_key)
      grid_weapon.weapon_key1 = weapon_key1
      grid_weapon.weapon_key2 = weapon_key2
      grid_weapon.weapon_key3 = nil
      expect(grid_weapon.weapon_keys).to match_array([weapon_key1, weapon_key2])
    end
  end

  describe '#blueprint' do
    it 'returns the GridWeaponBlueprint constant' do
      expect(grid_weapon.blueprint).to eq(GridWeaponBlueprint)
    end
  end
end
