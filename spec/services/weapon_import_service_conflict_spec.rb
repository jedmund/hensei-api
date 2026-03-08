# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponImportService, 'conflict resolution', type: :service do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:weapon_a) do
    Weapon.find_by(granblue_id: '1040020000') ||
      create(:weapon, granblue_id: '1040020000', name_en: 'Luminiera Sword Omega')
  end

  let(:weapon_b) do
    Weapon.find_by(granblue_id: '1040310600') ||
      create(:weapon, :transcendable, granblue_id: '1040310600', name_en: 'Yggdrasil Crystal Blade Omega')
  end

  before do
    weapon_a
    weapon_b
  end

  def game_item(game_id, granblue_id, evolution: 3, phase: 0)
    {
      'param' => {
        'id' => game_id,
        'image_id' => granblue_id,
        'evolution' => evolution,
        'phase' => phase
      },
      'master' => { 'id' => granblue_id }
    }
  end

  describe 'conflict_resolutions: import' do
    let!(:existing_null) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil, uncap_level: 2)
    end

    let(:game_data) { { 'list' => [game_item('12345', '1040020000', evolution: 5)] } }

    it 'updates the null-game_id record instead of creating a duplicate' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })

      expect { service.import }.not_to change(user.collection_weapons, :count)

      existing_null.reload
      expect(existing_null.game_id).to eq('12345')
      expect(existing_null.uncap_level).to eq(5)
    end

    it 'reports the item as updated, not created' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })
      result = service.import

      expect(result.updated.size).to eq(1)
      expect(result.created.size).to eq(0)
      expect(result.updated.first.id).to eq(existing_null.id)
    end

    it 'backfills game_id so future imports match normally' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })
      service.import

      # Second import should find by game_id and skip (no conflict resolution needed)
      service2 = described_class.new(user, game_data)
      result2 = service2.import

      expect(result2.skipped.size).to eq(1)
      expect(result2.created.size).to eq(0)
      expect(user.collection_weapons.count).to eq(1)
    end
  end

  describe 'conflict_resolutions: skip' do
    let!(:existing_null) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil, uncap_level: 2)
    end

    let(:game_data) { { 'list' => [game_item('12345', '1040020000', evolution: 5)] } }

    it 'does not update the existing record' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'skip' })
      service.import

      existing_null.reload
      expect(existing_null.game_id).to be_nil
      expect(existing_null.uncap_level).to eq(2)
    end

    it 'does not create a new record' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'skip' })

      expect { service.import }.not_to change(user.collection_weapons, :count)
    end

    it 'reports the item as skipped with user reason' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'skip' })
      result = service.import

      expect(result.skipped.size).to eq(1)
      expect(result.skipped.first[:reason]).to eq('Skipped by user')
    end
  end

  describe 'without conflict_resolutions (default behavior)' do
    let!(:existing_null) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil, uncap_level: 2)
    end

    let(:game_data) { { 'list' => [game_item('12345', '1040020000')] } }

    it 'creates a duplicate when no conflict resolution is provided' do
      service = described_class.new(user, game_data)

      expect { service.import }.to change(user.collection_weapons, :count).by(1)
    end

    it 'leaves the null-game_id record untouched' do
      service = described_class.new(user, game_data)
      service.import

      existing_null.reload
      expect(existing_null.game_id).to be_nil
      expect(existing_null.uncap_level).to eq(2)
    end
  end

  describe 'mixed batch with conflicts and normal items' do
    let!(:existing_null) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil, uncap_level: 2)
    end

    let(:game_data) do
      {
        'list' => [
          game_item('12345', '1040020000', evolution: 5),
          game_item('67890', '1040310600', evolution: 4)
        ]
      }
    end

    it 'resolves the conflict and creates the normal item' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })
      result = service.import

      expect(result.updated.size).to eq(1)
      expect(result.created.size).to eq(1)
      expect(result.created.first.weapon.granblue_id).to eq('1040310600')
    end

    it 'skips the conflict and still creates the normal item' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'skip' })
      result = service.import

      expect(result.skipped.size).to eq(1)
      expect(result.created.size).to eq(1)
    end
  end

  describe 'no conflict when game_id already matches' do
    let!(:existing_with_game_id) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: '12345', uncap_level: 2)
    end

    let(:game_data) { { 'list' => [game_item('12345', '1040020000', evolution: 5)] } }

    it 'finds existing by game_id and skips (ignores conflict_resolutions)' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })
      result = service.import

      # Should skip, not update — update_existing is false
      expect(result.skipped.size).to eq(1)
      expect(result.updated.size).to eq(0)
    end
  end

  describe 'conflict resolution scoped to correct user' do
    let!(:my_null) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil)
    end
    let!(:other_null) do
      create(:collection_weapon, user: other_user, weapon: weapon_a, game_id: nil)
    end

    let(:game_data) { { 'list' => [game_item('12345', '1040020000')] } }

    it 'only matches the current user null-game_id record' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })
      service.import

      my_null.reload
      other_null.reload

      expect(my_null.game_id).to eq('12345')
      expect(other_null.game_id).to be_nil
    end
  end

  describe 'nil game_id storage fix' do
    let(:game_data) do
      {
        'list' => [
          {
            'param' => {
              'id' => nil,
              'image_id' => '1040020000',
              'evolution' => 3,
              'phase' => 0
            },
            'master' => { 'id' => '1040020000' }
          }
        ]
      }
    end

    it 'stores nil instead of empty string when param.id is nil' do
      service = described_class.new(user, game_data)
      result = service.import

      expect(result.created.first.game_id).to be_nil
    end

    it 'stores nil instead of empty string when param.id is empty' do
      game_data['list'][0]['param']['id'] = ''
      service = described_class.new(user, game_data)
      result = service.import

      expect(result.created.first.game_id).to be_nil
    end
  end

  describe 'multiple null-game_id records for same weapon' do
    let!(:null_record_1) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil, uncap_level: 1)
    end
    let!(:null_record_2) do
      create(:collection_weapon, user: user, weapon: weapon_a, game_id: nil, uncap_level: 3)
    end

    let(:game_data) { { 'list' => [game_item('12345', '1040020000', evolution: 5)] } }

    it 'updates one of the null records (first found)' do
      service = described_class.new(user, game_data, conflict_resolutions: { '12345' => 'import' })
      result = service.import

      expect(result.updated.size).to eq(1)
      # Should not create a third record
      expect(user.collection_weapons.count).to eq(2)
    end
  end
end
