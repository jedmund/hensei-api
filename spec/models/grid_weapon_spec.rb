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
  it { is_expected.to belong_to(:collection_weapon).optional }

  # Setup common test objects using FactoryBot.
  let(:party) { create(:party) }
  let(:default_series) { create(:weapon_series, extra: false) }
  let(:weapon) { create(:weapon, limit: false, weapon_series: default_series) }
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
            # default_series has extra: false, so this should fail
            it 'adds an error on :series' do
              grid_weapon.validate
              expect(grid_weapon.errors[:series]).to include('must be compatible with position')
            end
          end

          context 'and weapon series is in allowed extra series' do
            let(:extra_series) { create(:weapon_series, extra: true) }
            let(:extra_weapon) { create(:weapon, limit: false, weapon_series: extra_series) }

            before { grid_weapon.weapon = extra_weapon }

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
          let(:limited_series) { create(:weapon_series) }
          let(:limited_weapon) { create(:weapon, limit: true, weapon_series: limited_series) }

          before do
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

  describe 'Collection Sync' do
    let(:user) { create(:user) }
    let(:ec_series) { create(:weapon_series, :element_changeable) }
    let(:ec_weapon) { create(:weapon, limit: false, weapon_series: ec_series) }
    let(:collection_weapon) do
      create(:collection_weapon,
             user: user,
             weapon: ec_weapon,
             uncap_level: 5,
             transcendence_step: 0,
             element: 2)
    end

    describe '#sync_from_collection!' do
      context 'when collection_weapon is linked' do
        let(:linked_grid_weapon) do
          create(:grid_weapon,
                 party: party,
                 weapon: ec_weapon,
                 position: 0,
                 collection_weapon: collection_weapon,
                 uncap_level: 3)
        end

        it 'copies customizations from collection' do
          expect(linked_grid_weapon.sync_from_collection!).to be true
          linked_grid_weapon.reload

          expect(linked_grid_weapon.uncap_level).to eq(5)
          expect(linked_grid_weapon.element).to eq(2)
        end
      end

      context 'when no collection_weapon is linked' do
        it 'returns false' do
          expect(grid_weapon.sync_from_collection!).to be false
        end
      end
    end

    describe '#out_of_sync?' do
      context 'when collection_weapon is linked' do
        let(:linked_grid_weapon) do
          create(:grid_weapon,
                 party: party,
                 weapon: ec_weapon,
                 position: 0,
                 collection_weapon: collection_weapon,
                 uncap_level: 3)
        end

        it 'returns true when values differ' do
          expect(linked_grid_weapon.out_of_sync?).to be true
        end

        it 'returns false after sync' do
          linked_grid_weapon.sync_from_collection!
          expect(linked_grid_weapon.out_of_sync?).to be false
        end
      end

      context 'when no collection_weapon is linked' do
        it 'returns false' do
          expect(grid_weapon.out_of_sync?).to be false
        end
      end
    end
  end
end
