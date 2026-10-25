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

  describe '#find_weapon' do
    let(:element_changeable_series) do
      WeaponSeries.find_by(slug: 'ultima') ||
        create(:weapon_series, element_changeable: true, slug: 'ultima')
    end

    let!(:ultima_axe) do
      Weapon.find_by(granblue_id: '1040307800') ||
        create(:weapon, name_en: 'Ultima Axe', granblue_id: '1040307800', element: 0, weapon_series: element_changeable_series,
                        element_variant_ids: {
                          '1' => '1040307800', '2' => '1040307900', '3' => '1040308000',
                          '4' => '1040308100', '5' => '1040308200', '6' => '1040308300'
                        })
    end

    it 'returns an exact match on granblue_id' do
      result = processor.send(:find_weapon, '1040307800', true, 'Ultima Axe')
      expect(result).to eq(ultima_axe)
    end

    it 'resolves element variants via element_variant_ids JSONB' do
      # Dark Ultima Axe — previously collided with Berserker's Barrage
      result = processor.send(:find_weapon, '1040308300', true, 'Ultima Axe')
      expect(result).to eq(ultima_axe)
    end

    it 'returns nil for unknown weapons' do
      result = processor.send(:find_weapon, '9999999999', false, 'Unknown')
      expect(result).to be_nil
    end

    it 'falls back to name matching when element_variant_ids is empty' do
      ultima_axe.update_column(:element_variant_ids, nil)
      result = processor.send(:find_weapon, '1040308300', true, 'Ultima Axe')
      expect(result).to eq(ultima_axe)
    end
  end

  describe '#process_augment_skills' do
    let(:grid_weapon) { build(:grid_weapon, party: party) }

    let!(:ax_hp_modifier) do
      WeaponStatModifier.find_by(slug: 'ax_hp') ||
        create(:weapon_stat_modifier, :ax_hp)
    end

    let!(:ax_ca_dmg_modifier) do
      WeaponStatModifier.find_by(slug: 'ax_ca_dmg') ||
        create(:weapon_stat_modifier, :ax_ca_dmg)
    end

    it 'assigns ax_modifier_id and ax_strength from nested augment_skill_info' do
      param = {
        'augment_skill_info' => [
          [
            { 'skill_id' => '1588', 'effect_value' => '3', 'show_value' => '3%' },
            { 'skill_id' => '1591', 'effect_value' => '5', 'show_value' => '5%' }
          ]
        ]
      }
      processor.send(:process_augment_skills, grid_weapon, param)
      expect(grid_weapon.ax_modifier1).to eq(ax_hp_modifier)
      expect(grid_weapon.ax_strength1).to eq(3.0)
      expect(grid_weapon.ax_modifier2).to eq(ax_ca_dmg_modifier)
      expect(grid_weapon.ax_strength2).to eq(5.0)
    end

    it 'maps skill_id 1598 to the Skill DMG Cap AX roll' do
      skill_cap_modifier = create(:weapon_stat_modifier, :ax_skill_cap)
      param = {
        'augment_skill_info' => [
          [
            { 'skill_id' => 1588, 'effect_value' => '3', 'show_value' => '+3%' },
            { 'skill_id' => 1598, 'effect_value' => '1', 'show_value' => '+1%' }
          ]
        ]
      }
      processor.send(:process_augment_skills, grid_weapon, param)
      expect(grid_weapon.ax_modifier2).to eq(skill_cap_modifier)
      expect(grid_weapon.ax_strength2).to eq(1.0)
    end
  end

  # Excerpts from a real party-deck response (deck "Gold3")
  describe 'augment skills and skill levels from a real deck' do
    let!(:befoulment_modifier) { create(:weapon_stat_modifier, :befoul_atk_down) }
    let!(:ax_atk_modifier) { WeaponStatModifier.find_by(game_skill_id: 1589) || create(:weapon_stat_modifier, :ax_atk) }
    let!(:ax_skill_cap_modifier) { create(:weapon_stat_modifier, :ax_skill_cap) }
    let!(:odious_weapon) do
      Weapon.find_by(granblue_id: '1040220800') ||
        create(:weapon, :odiant, granblue_id: '1040220800', name_en: 'Demonspear of Prosperity Verboten')
    end
    let!(:ax_weapon) do
      Weapon.find_by(granblue_id: '1040401500') ||
        create(:weapon, :with_ax, granblue_id: '1040401500', name_en: 'Colossus Cane Omega')
    end

    let(:odious_param) do
      {
        'id' => 54_321,
        'level' => '150',
        'augment_skill_info' => [[{ 'depth' => 2, 'effect_value' => 6.2, 'show_value' => '-6.2%', 'skill_id' => 2873 }]],
        'augment_skill_icon_image' => ['ex_skill_atk_down'],
        'odiant' => { 'exorcision_level' => 5, 'is_odiant_weapon' => true, 'max_exorcision_level' => 5,
                      'reduction_effect_value' => 180 },
        'skill_level' => '15'
      }
    end

    let(:ax_param) do
      {
        'id' => 65_432,
        'level' => '150',
        'augment_skill_info' => [[
          { 'depth' => nil, 'effect_value' => '2.5', 'show_value' => '+2.5%', 'skill_id' => 1589 },
          { 'depth' => nil, 'effect_value' => '1', 'show_value' => '+1%', 'skill_id' => 1598 }
        ]],
        'augment_skill_icon_image' => %w[ex_skill_atk ex_skill_ab_limit],
        'odiant' => { 'exorcision_level' => 0, 'is_odiant_weapon' => false, 'max_exorcision_level' => 0,
                      'reduction_effect_value' => 0 },
        'skill_level' => '20'
      }
    end

    let(:deck) do
      {
        'deck' => {
          'pc' => {
            'weapons' => {
              '2' => { 'master' => { 'id' => '1040220800', 'name' => odious_weapon.name_en, 'series_id' => '0' },
                       'param' => odious_param },
              '6' => { 'master' => { 'id' => '1040401500', 'name' => ax_weapon.name_en, 'series_id' => '0' },
                       'param' => ax_param }
            }
          }
        }
      }
    end

    subject { described_class.new(party, deck) }

    it "stores the Odious weapon's befoulment, permeation, exorcision and skill levels" do
      subject.process

      grid_weapon = party.weapons.find_by(weapon: odious_weapon)
      expect(grid_weapon.befoulment_modifier).to eq(befoulment_modifier)
      # effect_value is the magnitude; the sign is only in show_value
      expect(grid_weapon.befoulment_strength).to eq(6.2)
      expect(grid_weapon.befoulment_permeation).to eq(2)
      expect(grid_weapon.exorcism_level).to eq(5)
      expect(grid_weapon.skill_level).to eq(15)
      expect(grid_weapon.ax_modifier1_id).to be_nil
      expect(subject.warnings).to be_empty
    end

    it "stores the AX weapon's Skill DMG Cap roll and skill level" do
      subject.process

      grid_weapon = party.weapons.find_by(weapon: ax_weapon)
      expect(grid_weapon.ax_modifier1).to eq(ax_atk_modifier)
      expect(grid_weapon.ax_strength1).to eq(2.5)
      expect(grid_weapon.ax_modifier2).to eq(ax_skill_cap_modifier)
      expect(grid_weapon.ax_strength2).to eq(1.0)
      expect(grid_weapon.skill_level).to eq(20)
      expect(grid_weapon.befoulment_permeation).to be_nil
    end

    it 'keeps the values through the collection sync and updates the collection weapons' do
      odious_copy = create(:collection_weapon, user: party.user, weapon: odious_weapon, game_id: '54321')
      ax_copy = create(:collection_weapon, user: party.user, weapon: ax_weapon, game_id: '65432')

      subject.process

      grid_weapon = party.weapons.find_by(weapon: odious_weapon)
      expect(grid_weapon.collection_weapon).to eq(odious_copy)
      expect(grid_weapon.befoulment_permeation).to eq(2)
      expect(grid_weapon.exorcism_level).to eq(5)
      expect(grid_weapon.skill_level).to eq(15)

      odious_copy.reload
      expect(odious_copy.befoulment_modifier).to eq(befoulment_modifier)
      expect(odious_copy.befoulment_strength).to eq(6.2)
      expect(odious_copy.befoulment_permeation).to eq(2)
      expect(odious_copy.exorcism_level).to eq(5)
      expect(odious_copy.skill_level).to eq(15)
      expect(ax_copy.reload.skill_level).to eq(20)
    end

    it 'keeps stored permeation and skill level when the game omits them' do
      odious_param['augment_skill_info'][0][0].delete('depth')
      odious_param.delete('skill_level')
      odious_copy = create(:collection_weapon, user: party.user, weapon: odious_weapon, game_id: '54321',
                                               befoulment_permeation: 4, skill_level: 12)

      subject.process

      grid_weapon = party.weapons.find_by(weapon: odious_weapon)
      expect(grid_weapon.befoulment_permeation).to eq(4)
      expect(grid_weapon.skill_level).to eq(12)
      expect(odious_copy.reload.befoulment_permeation).to eq(4)
      expect(odious_copy.skill_level).to eq(12)
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

  describe 'AX skills survive collection sync' do
    # Weapon 10 in deck_sample2 is Celeste Zaghnal Omega with augment_skill_info skill_id=1589 (ax_atk)
    let(:deck_data) do
      file_path = Rails.root.join('spec', 'fixtures', 'deck_sample2.json')
      JSON.parse(File.read(file_path))
    end

    let!(:ax_atk_modifier) do
      WeaponStatModifier.find_by(game_skill_id: 1589) ||
        create(:weapon_stat_modifier, :ax_atk)
    end

    let!(:ax_weapon) do
      weapon = Weapon.find_by!(granblue_id: '1040301400')
      weapon.update!(weapon_series: create(:weapon_series, :with_ax_skills))
      weapon
    end

    subject { described_class.new(party, deck_data) }

    it 'preserves AX skills on grid weapon after collection sync' do
      subject.process

      # Weapon 10 maps to position 8 (key 10, position = 10 - 2 = 8)
      grid_weapon = party.weapons.find_by(position: 8)
      expect(grid_weapon).to be_present
      expect(grid_weapon.ax_modifier1_id).to eq(ax_atk_modifier.id)
      expect(grid_weapon.ax_strength1).to eq(3.2)
    end
  end

  describe 'weapons that fail validation' do
    let!(:ax_atk_modifier) do
      WeaponStatModifier.find_by(game_skill_id: 1589) ||
        create(:weapon_stat_modifier, :ax_atk)
    end

    let!(:ax_weapon) { create(:weapon, :with_ax, granblue_id: '1040399900') }

    # ATK's primary range is 1-3.5, so 9% fails AxSkillValidation.
    let(:invalid_ax_deck) do
      {
        'deck' => {
          'pc' => {
            'weapons' => {
              '1' => {
                'master' => { 'id' => '1040399900', 'name' => ax_weapon.name_en, 'series_id' => '0' },
                'param' => {
                  'id' => 12_345,
                  'level' => '150',
                  'augment_skill_info' => [[{ 'skill_id' => 1589, 'effect_value' => '9', 'show_value' => '+9%' }]]
                }
              }
            }
          }
        }
      }
    end

    subject { described_class.new(party, invalid_ax_deck) }

    it 'does not leave the invalid record on the party association' do
      subject.process

      expect(party.weapons.select(&:new_record?)).to be_empty
      expect { party.update!(name: 'Renamed') }.not_to raise_error
    end

    it 'keeps the weapon and drops its invalid AX skills' do
      expect { subject.process }.to change(GridWeapon, :count).by(1)

      grid_weapon = party.weapons.find_by(position: -1)
      expect(grid_weapon.weapon).to eq(ax_weapon)
      expect(grid_weapon.ax_modifier1_id).to be_nil
      expect(grid_weapon.ax_strength1).to be_nil
    end

    it 'reports the dropped AX skills as a warning' do
      subject.process

      expect(subject.warnings).to contain_exactly(
        a_hash_including(code: 'ax_skills_dropped', type: 'weapon', position: -1, granblue_id: '1040399900')
      )
    end
  end

  describe 'element-changeable weapon resolution (integration)' do
    let(:element_changeable_series) do
      WeaponSeries.find_by(slug: 'ultima') ||
        create(:weapon_series, element_changeable: true, slug: 'ultima')
    end
    let!(:excalibur) do
      Weapon.find_by(granblue_id: '1040002000') ||
        create(:weapon, name_en: 'Excalibur', granblue_id: '1040002000', element: 0, weapon_series: element_changeable_series)
    end

    let(:dark_excalibur_deck) do
      {
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
    end

    it 'resolves via element_variant_ids when populated' do
      excalibur.update!(element_variant_ids: { '6' => '1040007900' })

      proc = described_class.new(party, dark_excalibur_deck)
      expect { proc.process }.to change(GridWeapon, :count).by(1)

      grid_weapon = party.weapons.find_by(position: -1)
      expect(grid_weapon.weapon).to eq(excalibur)
      expect(grid_weapon.element).to eq(6)
    end

    it 'resolves a null-element weapon variant by name when element_variant_ids is empty' do
      proc = described_class.new(party, dark_excalibur_deck)
      expect { proc.process }.to change(GridWeapon, :count).by(1)

      grid_weapon = party.weapons.find_by(position: -1)
      expect(grid_weapon).not_to be_nil
      expect(grid_weapon.weapon).to eq(excalibur)
      expect(grid_weapon.element).to eq(6) # Dark
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
