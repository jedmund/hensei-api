# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Grid model substitution behavior', type: :model do
  let(:party) { create(:party) }
  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:other_weapon) { Weapon.find_by!(granblue_id: '1040912100') }
  let(:character) { Character.find_by!(granblue_id: '3040087000') }

  describe 'counter cache behavior' do
    it 'increments weapons_count for normal grid weapons' do
      expect do
        create(:grid_weapon, party: party, weapon: weapon, position: 0)
      end.to change { party.reload.weapons_count }.by(1)
    end

    it 'does not increment weapons_count for substitute grid weapons' do
      expect do
        create(:grid_weapon, party: party, weapon: weapon, position: 0, is_substitute: true)
      end.not_to(change { party.reload.weapons_count })
    end

    it 'decrements weapons_count when normal grid weapon is destroyed' do
      gw = create(:grid_weapon, party: party, weapon: weapon, position: 0)
      expect do
        gw.destroy
      end.to change { party.reload.weapons_count }.by(-1)
    end

    it 'does not decrement weapons_count when substitute is destroyed' do
      sw = create(:grid_weapon, party: party, weapon: weapon, position: 0, is_substitute: true)
      expect do
        sw.destroy
      end.not_to(change { party.reload.weapons_count })
    end

    it 'increments characters_count for normal grid characters' do
      expect do
        create(:grid_character, party: party, position: 0)
      end.to change { party.reload.characters_count }.by(1)
    end

    it 'does not increment characters_count for substitute grid characters' do
      expect do
        create(:grid_character, party: party, position: 0, is_substitute: true)
      end.not_to(change { party.reload.characters_count })
    end
  end

  describe 'party association scoping' do
    it 'excludes substitutes from party.weapons' do
      create(:grid_weapon, party: party, weapon: weapon, position: 0)
      create(:grid_weapon, party: party, weapon: other_weapon, position: 0, is_substitute: true)

      expect(party.weapons.count).to eq(1)
      expect(party.weapons.first.is_substitute).to be false
    end

    it 'includes substitutes in party.all_weapons' do
      create(:grid_weapon, party: party, weapon: weapon, position: 0)
      create(:grid_weapon, party: party, weapon: other_weapon, position: 0, is_substitute: true)

      expect(party.all_weapons.count).to eq(2)
    end

    it 'excludes substitutes from party.characters' do
      create(:grid_character, party: party, position: 0)
      create(:grid_character, party: party, position: 0, is_substitute: true)

      expect(party.characters.count).to eq(1)
    end

    it 'includes substitutes in party.all_characters' do
      create(:grid_character, party: party, position: 0)
      create(:grid_character, party: party, position: 0, is_substitute: true)

      expect(party.all_characters.count).to eq(2)
    end
  end

  describe 'validation guards for substitutes' do
    context 'GridWeapon' do
      let(:default_series) { create(:weapon_series, extra: false) }
      let(:limited_weapon) { create(:weapon, limit: true, weapon_series: default_series) }

      it 'skips compatible_with_position for substitutes' do
        # Position 9 is extra-only, but substitutes should bypass this check
        sw = build(:grid_weapon, party: party, weapon: weapon, position: 9, is_substitute: true)
        sw.valid?
        expect(sw.errors[:series]).to be_empty
      end

      it 'skips no_conflicts for substitutes' do
        # Create two substitute weapons with the same limited weapon — no conflict error
        create(:grid_weapon, party: party, weapon: limited_weapon, position: 0)
        sw = build(:grid_weapon, party: party, weapon: limited_weapon, position: 0, is_substitute: true)
        expect(sw).to be_valid
      end
    end

    context 'GridCharacter' do
      it 'skips awakening validation for substitute characters on update' do
        gc = create(:grid_character, party: party, position: 0, is_substitute: true)
        # Setting awakening_level to 0 would normally fail validate_awakening_level
        gc.awakening_level = 0
        gc.valid?(:update)
        expect(gc.errors[:awakening]).to be_empty
      end
    end
  end

  describe 'role slot type matching' do
    let(:char_role) { create(:role, slot_type: 'Character') }
    let(:weapon_role) { create(:role, :weapon) }

    it 'allows matching role for GridCharacter' do
      gc = build(:grid_character, party: party, position: 0, role: char_role)
      gc.valid?
      expect(gc.errors[:role]).to be_empty
    end

    it 'rejects mismatched role for GridCharacter' do
      gc = build(:grid_character, party: party, position: 0, role: weapon_role)
      gc.valid?
      expect(gc.errors[:role]).to include('slot type must be Character')
    end

    it 'allows matching role for GridWeapon' do
      gw = build(:grid_weapon, party: party, weapon: weapon, position: 0, role: weapon_role)
      gw.valid?
      expect(gw.errors[:role]).to be_empty
    end

    it 'rejects mismatched role for GridWeapon' do
      gw = build(:grid_weapon, party: party, weapon: weapon, position: 0, role: char_role)
      gw.valid?
      expect(gw.errors[:role]).to include('slot type must be Weapon')
    end

    it 'allows nil role (optional)' do
      gw = build(:grid_weapon, party: party, weapon: weapon, position: 0, role: nil)
      gw.valid?
      expect(gw.errors[:role]).to be_empty
    end
  end

  describe 'amoeba duplication' do
    it 'nullifies role_id and substitution_note on weapon duplication' do
      role = create(:role, :weapon)
      gw = create(:grid_weapon, party: party, weapon: weapon, position: 0,
                                role: role, substitution_note: 'Use this for fire teams')
      dup = gw.amoeba_dup
      expect(dup.role_id).to be_nil
      expect(dup.substitution_note).to be_nil
    end

    it 'nullifies role_id and substitution_note on character duplication' do
      role = create(:role, slot_type: 'Character')
      gc = create(:grid_character, party: party, position: 0,
                                   role: role, substitution_note: 'Flex slot')
      dup = gc.amoeba_dup
      expect(dup.role_id).to be_nil
      expect(dup.substitution_note).to be_nil
    end
  end
end
