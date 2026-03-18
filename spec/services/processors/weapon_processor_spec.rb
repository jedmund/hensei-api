# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Processors::WeaponProcessor, type: :model do
  let(:party) { create(:party) }
  # Minimal deck data for testing private methods.
  let(:dummy_deck_data) { { 'deck' => { 'pc' => { 'weapons' => {} } } } }
  let(:processor) { described_class.new(party, dummy_deck_data) }

  describe '#level_to_transcendence' do
    it 'returns 0 for levels less than 200' do
      expect(processor.send(:level_to_transcendence, 150)).to eq(0)
    end

    it 'returns the correct transcendence step for levels >= 200' do
      expect(processor.send(:level_to_transcendence, 200)).to eq(0)
      expect(processor.send(:level_to_transcendence, 215)).to eq(1)
      expect(processor.send(:level_to_transcendence, 250)).to eq(5)
    end
  end

  describe '#matches_key?' do
    it 'returns true if candidate key falls within a range' do
      expect(processor.send(:matches_key?, '700', '697-706')).to be true
    end

    it 'returns false if candidate key is below the range' do
      expect(processor.send(:matches_key?, '696', '697-706')).to be false
    end

    it 'returns false if candidate key is above the range' do
      expect(processor.send(:matches_key?, '707', '697-706')).to be false
    end

    it 'returns true if candidate key exactly matches the mapping' do
      expect(processor.send(:matches_key?, '700', '700')).to be true
    end
  end

  describe '#process_weapon_ax' do
    let(:grid_weapon) { build(:grid_weapon, party: party) }

    let!(:ax_hp_modifier) do
      WeaponStatModifier.find_by(slug: 'ax_hp') ||
        create(:weapon_stat_modifier, :ax_hp)
    end

    let!(:ax_ca_dmg_modifier) do
      WeaponStatModifier.find_by(slug: 'ax_ca_dmg') ||
        create(:weapon_stat_modifier,
               slug: 'ax_ca_dmg',
               name_en: 'C.A. DMG',
               category: 'ax',
               stat: 'ca_dmg',
               polarity: 1,
               suffix: '%',
               game_skill_id: 1591)
    end

    it 'flattens nested augment_skill_info and assigns ax_modifier_id and ax_strength' do
      ax_skill_info = [
        [
          { 'skill_id' => '1588', 'effect_value' => '3', 'show_value' => '3%' },
          { 'skill_id' => '1591', 'effect_value' => '5', 'show_value' => '5%' }
        ]
      ]
      processor.send(:process_weapon_ax, grid_weapon, ax_skill_info)
      expect(grid_weapon.ax_modifier1).to eq(ax_hp_modifier)
      expect(grid_weapon.ax_strength1).to eq(3.0)
      expect(grid_weapon.ax_modifier2).to eq(ax_ca_dmg_modifier)
      expect(grid_weapon.ax_strength2).to eq(5.0)
    end
  end

  describe '#map_arousal_to_awakening' do
    it 'returns nil if there is no form key' do
      arousal_data = {}
      expect(processor.send(:map_arousal_to_awakening, arousal_data)).to be_nil
    end

    it 'returns the awakening id if found' do
      arousal_data = {
        "is_arousal_weapon": true,
        "level": 4,
        "form": 2,
        "form_name": 'Defense',
        "remain_for_next_level": 0,
        "width": 100,
        "is_complete_condition": true,
        "max_level": 4,
      }

      awakening = Awakening.find_by(slug: 'weapon-def')
      expect(processor.send(:map_arousal_to_awakening, arousal_data)).to eq(awakening.id)
    end
  end

  describe '#process_weapon_keys' do
    let(:deck_data) do
      file_path = Rails.root.join('spec', 'fixtures', 'deck_sample2.json')
      JSON.parse(File.read(file_path))
    end

    let(:deck_weapon) do
      deck_data['deck']['pc']['weapons']['7']
    end

    let(:canonical_weapon) do
      Weapon.find_by(granblue_id: deck_weapon['master']['id'])
    end

    let(:grid_weapon) do
      create(:grid_weapon, weapon: canonical_weapon, party: party)
    end

    context 'when the raw key is provided via KEY_MAPPING' do
      xit 'assigns the mapped WeaponKey (requires weapon_series seed data for weapon key mapping)' do
        skill_ids = [deck_weapon['skill1'], deck_weapon['skill2'], deck_weapon['skill3']].compact.map { |s| s['id'] }
        processor.send(:process_weapon_keys, grid_weapon, skill_ids)
        expect(grid_weapon.weapon_key1_id).to be_nil
        expect(grid_weapon.weapon_key2_id).to eq(WeaponKey.find_by(slug: 'pendulum-beta').id)
        expect(grid_weapon.weapon_key3_id).to eq(WeaponKey.find_by(slug: 'pendulum-extremity').id)
      end
    end

    context 'when no matching WeaponKey is found' do
      it 'logs a warning and does not assign the key' do
        processor.send(:process_weapon_keys, grid_weapon, ['unknown'])
        expect(grid_weapon.weapon_key1_id).to be_nil
      end
    end
  end

  describe '#process_elemental_weapon name fallback' do
    let(:element_changeable_series) do
      WeaponSeries.find_by(slug: 'ultima') ||
        create(:weapon_series, element_changeable: true, slug: 'ultima')
    end
    let!(:excalibur) do
      Weapon.find_by(granblue_id: '1040002000') ||
        create(:weapon, name_en: 'Excalibur', granblue_id: '1040002000', element: 0, weapon_series: element_changeable_series)
    end

    it 'resolves a null-element weapon variant by name when ID proximity fails' do
      deck_data = {
        'deck' => {
          'pc' => {
            'weapons' => {
              '1' => {
                'master' => {
                  'id' => '1040007900',
                  'name' => 'Excalibur',
                  'attribute' => '6',
                  'series_id' => '13',
                  'kind' => '1',
                  'rarity' => '4'
                },
                'param' => {
                  'id' => 999,
                  'level' => '150',
                  'image_id' => '1040007900'
                }
              }
            }
          }
        }
      }

      proc = described_class.new(party, deck_data)
      expect { proc.process }.to change(GridWeapon, :count).by(1)

      grid_weapon = party.weapons.find_by(position: -1)
      expect(grid_weapon).not_to be_nil
      expect(grid_weapon.weapon).to eq(excalibur)
      expect(grid_weapon.element).to eq(5) # Dark
    end
  end

  describe 'processing a complete canonical deck' do
    let(:deck_data) do
      file_path = Rails.root.join('spec', 'fixtures', 'deck_sample2.json')
      JSON.parse(File.read(file_path))
    end

    subject { described_class.new(party, deck_data) }

    it 'processes the deck and creates the expected number of GridWeapon records' do
      # Assume the canonical records are already loaded (via canonical.rb).
      expect { subject.process }.to change(GridWeapon, :count).by(13)
    end

    it 'creates the correct main weapon' do
      subject.process
      # In this canonical deck, the main weapon (slot 1) should be Parazonium.
      main_weapon = party.weapons.find_by(position: -1)
      expect(main_weapon).not_to be_nil
      expect(main_weapon.weapon.granblue_id).to eq('1040108700')
    end
  end
end
