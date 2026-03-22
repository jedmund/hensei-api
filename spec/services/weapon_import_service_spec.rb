# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponImportService, type: :service do
  let(:user) { create(:user) }

  # Create weapons with specific granblue_ids matching the game data
  let(:standard_weapon) do
    Weapon.find_by(granblue_id: '1040020000') ||
      create(:weapon, granblue_id: '1040020000', name_en: 'Luminiera Sword Omega')
  end

  let(:transcendable_weapon) do
    Weapon.find_by(granblue_id: '1040310600') ||
      create(:weapon, :transcendable, granblue_id: '1040310600', name_en: 'Yggdrasil Crystal Blade Omega')
  end

  let(:awakened_weapon) do
    Weapon.find_by(granblue_id: '1040914400') ||
      create(:weapon, granblue_id: '1040914400', name_en: 'Yamato Katana')
  end

  let(:ax_weapon) do
    Weapon.find_by(granblue_id: '1040213900') ||
      create(:weapon, :ax_weapon, granblue_id: '1040213900', name_en: 'Celeste Claw Omega')
  end

  # Create weapon awakenings
  let!(:awakening_atk) do
    Awakening.find_by(slug: 'weapon-atk', object_type: 'Weapon') ||
      create(:awakening, :for_weapon, slug: 'weapon-atk', name_en: 'Attack')
  end

  let!(:awakening_def) do
    Awakening.find_by(slug: 'weapon-def', object_type: 'Weapon') ||
      create(:awakening, :for_weapon, slug: 'weapon-def', name_en: 'Defense')
  end

  let!(:awakening_special) do
    Awakening.find_by(slug: 'weapon-special', object_type: 'Weapon') ||
      create(:awakening, :for_weapon, slug: 'weapon-special', name_en: 'Special')
  end

  let!(:awakening_ca) do
    Awakening.find_by(slug: 'weapon-ca', object_type: 'Weapon') ||
      create(:awakening, :for_weapon, slug: 'weapon-ca', name_en: 'C.A.')
  end

  let!(:awakening_skill) do
    Awakening.find_by(slug: 'weapon-skill', object_type: 'Weapon') ||
      create(:awakening, :for_weapon, slug: 'weapon-skill', name_en: 'Skill DMG')
  end

  let!(:awakening_heal) do
    Awakening.find_by(slug: 'weapon-heal', object_type: 'Weapon') ||
      create(:awakening, :for_weapon, slug: 'weapon-heal', name_en: 'Healing')
  end

  # Create weapon stat modifiers for AX skill tests
  let!(:ax_atk_modifier) do
    WeaponStatModifier.find_by(slug: 'ax_atk') ||
      create(:weapon_stat_modifier, :ax_atk)
  end

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

  before do
    standard_weapon
    transcendable_weapon
    awakened_weapon
    ax_weapon
  end

  describe '#import' do
    context 'with valid game data' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '49858531',
                'image_id' => '1040020000',
                'evolution' => 3,
                'phase' => 0
              },
              'master' => {
                'id' => '1040020000',
                'name' => 'Luminiera Sword Omega'
              }
            }
          ]
        }
      end

      it 'creates a collection weapon' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.errors).to be_empty
      end

      it 'sets the correct game_id' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.game_id).to eq('49858531')
      end

      it 'sets the correct uncap_level from evolution' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.uncap_level).to eq(3)
      end

      it 'associates the correct weapon via granblue_id' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.weapon.granblue_id).to eq('1040020000')
      end
    end

    context 'with transcendence data' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '53169135',
                'image_id' => '1040310600',
                'evolution' => 5,
                'phase' => 6
              },
              'master' => {
                'id' => '1040310600',
                'name' => 'Yggdrasil Crystal Blade Omega'
              }
            }
          ]
        }
      end

      it 'sets transcendence_step from phase' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.transcendence_step).to eq(6)
      end

      it 'sets uncap_level to 6 for transcended weapons' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.uncap_level).to eq(6)
      end
    end

    context 'with awakening data' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '96548732',
                'image_id' => '1040914400',
                'evolution' => 5,
                'phase' => 0,
                'arousal' => {
                  'is_arousal_weapon' => true,
                  'level' => 15,
                  'form' => 1,
                  'form_name' => 'Attack'
                }
              },
              'master' => {
                'id' => '1040914400',
                'name' => 'Yamato Katana'
              }
            }
          ]
        }
      end

      it 'sets awakening_id based on form' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.awakening).to eq(awakening_atk)
      end

      it 'sets awakening_level from arousal level' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.awakening_level).to eq(15)
      end
    end

    context 'with different awakening forms' do
      {
        1 => 'weapon-atk',
        2 => 'weapon-def',
        3 => 'weapon-special',
        4 => 'weapon-ca',
        5 => 'weapon-skill',
        6 => 'weapon-heal'
      }.each do |form, slug|
        it "maps awakening form #{form} to #{slug}" do
          game_data = {
            'list' => [
              {
                'param' => {
                  'id' => "test_#{form}",
                  'image_id' => '1040914400',
                  'evolution' => 5,
                  'phase' => 0,
                  'arousal' => {
                    'is_arousal_weapon' => true,
                    'level' => 10,
                    'form' => form
                  }
                },
                'master' => { 'id' => '1040914400' }
              }
            ]
          }

          service = described_class.new(user, game_data)
          result = service.import

          expect(result.created.first.awakening.slug).to eq(slug)
        end
      end
    end

    context 'with no awakening' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '12345678',
                'image_id' => '1040020000',
                'evolution' => 3,
                'phase' => 0,
                'arousal' => {
                  'is_arousal_weapon' => false
                }
              },
              'master' => { 'id' => '1040020000' }
            }
          ]
        }
      end

      it 'does not set awakening when is_arousal_weapon is false' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.awakening).to be_nil
        expect(weapon.awakening_level).to eq(1) # default value
      end
    end

    context 'with AX skills' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '55555555',
                'image_id' => '1040213900',
                'evolution' => 5,
                'phase' => 0,
                'augment_skill_info' => [
                  [
                    {
                      'skill_id' => 1589,  # ATK modifier
                      'effect_value' => '7',
                      'show_value' => '7%'
                    },
                    {
                      'skill_id' => 1588,  # HP modifier
                      'effect_value' => '2_4',
                      'show_value' => '4%'
                    }
                  ]
                ]
              },
              'master' => { 'id' => '1040213900' }
            }
          ]
        }
      end

      it 'parses first AX skill correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.ax_modifier1).to eq(ax_atk_modifier)
        expect(weapon.ax_strength1).to eq(7.0)
      end

      it 'parses second AX skill with underscore format' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.ax_modifier2).to eq(ax_hp_modifier)
        expect(weapon.ax_strength2).to eq(4.0)
      end
    end

    context 'with show_value format for AX strength' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '66666666',
                'image_id' => '1040213900',
                'evolution' => 5,
                'phase' => 0,
                'augment_skill_info' => [
                  [
                    {
                      'skill_id' => 1591,  # C.A. DMG modifier
                      'effect_value' => nil,
                      'show_value' => '5.5%'
                    }
                  ]
                ]
              },
              'master' => { 'id' => '1040213900' }
            }
          ]
        }
      end

      it 'parses strength from show_value when effect_value is nil' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.ax_modifier1).to eq(ax_ca_dmg_modifier)
        expect(weapon.ax_strength1).to eq(5.5)
      end
    end

    context 'with duplicate game_id' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '99999999',
                'image_id' => '1040020000',
                'evolution' => 3,
                'phase' => 0
              },
              'master' => { 'id' => '1040020000' }
            }
          ]
        }
      end

      before do
        create(:collection_weapon, user: user, weapon: standard_weapon, game_id: '99999999')
      end

      it 'skips the duplicate' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(0)
        expect(result.skipped.size).to eq(1)
        expect(result.skipped.first[:reason]).to eq('Already exists')
      end

      context 'with update_existing: true' do
        let(:game_data_updated) do
          {
            'list' => [
              {
                'param' => {
                  'id' => '99999999',
                  'image_id' => '1040020000',
                  'evolution' => 5,
                  'phase' => 0
                },
                'master' => { 'id' => '1040020000' }
              }
            ]
          }
        end

        it 'updates the existing weapon' do
          service = described_class.new(user, game_data_updated, update_existing: true)
          result = service.import

          expect(result.success?).to be true
          expect(result.created.size).to eq(0)
          expect(result.updated.size).to eq(1)
          expect(result.updated.first.uncap_level).to eq(5)
        end
      end
    end

    context 'with unknown weapon' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '12345',
                'image_id' => '9999999999',
                'evolution' => 3,
                'phase' => 0
              },
              'master' => { 'id' => '9999999999' }
            }
          ]
        }
      end

      it 'records an error for the unknown weapon' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:error]).to eq('Weapon not found')
      end
    end

    context 'with multiple weapons' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '11111111',
                'image_id' => '1040020000',
                'evolution' => 3,
                'phase' => 0
              },
              'master' => { 'id' => '1040020000' }
            },
            {
              'param' => {
                'id' => '22222222',
                'image_id' => '1040310600',
                'evolution' => 5,
                'phase' => 3
              },
              'master' => { 'id' => '1040310600' }
            }
          ]
        }
      end

      it 'imports all weapons' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(2)
      end

      it 'associates correct weapons' do
        service = described_class.new(user, game_data)
        result = service.import

        weapons = result.created.sort_by(&:game_id)
        expect(weapons[0].weapon.granblue_id).to eq('1040020000')
        expect(weapons[1].weapon.granblue_id).to eq('1040310600')
      end
    end

    context 'with empty data' do
      let(:game_data) { { 'list' => [] } }

      it 'returns an error' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be false
        expect(result.errors).to include('No weapon items found in data')
      end
    end

    context 'with array format data' do
      let(:game_data) do
        [
          {
            'param' => {
              'id' => '77777777',
              'image_id' => '1040020000',
              'evolution' => 4,
              'phase' => 0
            },
            'master' => { 'id' => '1040020000' }
          }
        ]
      end

      it 'handles array format correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.created.first.uncap_level).to eq(4)
      end
    end

    context 'with max uncap/transcendence values' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '88888888',
                'image_id' => '1040310600',
                'evolution' => 10,
                'phase' => 15
              },
              'master' => { 'id' => '1040310600' }
            }
          ]
        }
      end

      it 'clamps uncap_level to max 6 for transcended weapons' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.uncap_level).to eq(6)
      end

      it 'clamps transcendence_step to max 10' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.transcendence_step).to eq(10)
      end
    end

    context 'with max awakening level' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '10101010',
                'image_id' => '1040914400',
                'evolution' => 5,
                'phase' => 0,
                'arousal' => {
                  'is_arousal_weapon' => true,
                  'level' => 25,
                  'form' => 1
                }
              },
              'master' => { 'id' => '1040914400' }
            }
          ]
        }
      end

      it 'clamps awakening_level to max 20' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.awakening_level).to eq(20)
      end
    end

    context 'with image_id from master.id fallback' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '33333333',
                'evolution' => 3,
                'phase' => 0
              },
              'master' => {
                'id' => '1040020000'
              }
            }
          ]
        }
      end

      it 'uses master.id when param.image_id is missing' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.weapon.granblue_id).to eq('1040020000')
      end
    end
  end

  describe 'edge cases' do
    context 'with nil arousal' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '44444444',
                'image_id' => '1040020000',
                'evolution' => 3,
                'phase' => 0,
                'arousal' => nil
              },
              'master' => { 'id' => '1040020000' }
            }
          ]
        }
      end

      it 'handles nil arousal gracefully' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.awakening).to be_nil
      end
    end

    context 'with empty augment_skill_info' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => '55556666',
                'image_id' => '1040213900',
                'evolution' => 5,
                'phase' => 0,
                'augment_skill_info' => []
              },
              'master' => { 'id' => '1040213900' }
            }
          ]
        }
      end

      it 'handles empty augment_skill_info gracefully' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.ax_modifier1).to be_nil
        expect(result.created.first.ax_modifier2).to be_nil
      end
    end
  end

  describe 'element-changeable weapons' do
    let(:ccw_series) do
      WeaponSeries.find_by(slug: 'class-champion') ||
        create(:weapon_series, :class_champion)
    end

    # Skofnung: base granblue_id is 1040005200 which also happens to be the Fire variant.
    # Wind variant is 1040005500, Water is 1040005300, etc.
    let(:ccw_weapon) do
      create(:weapon,
             granblue_id: '1040005200',
             name_en: 'Skofnung',
             element: 0,
             weapon_series: ccw_series,
             element_variant_ids: {
               '1' => '1040005500', # Wind
               '2' => '1040005200', # Fire (same as base granblue_id)
               '3' => '1040005300', # Water
               '4' => '1040005400', # Earth
               '5' => '1040005700', # Dark
               '6' => '1040005600'  # Light
             })
    end

    def weapon_item(game_id:, image_id:, evolution: '5', phase: '0')
      {
        'param' => {
          'id' => game_id,
          'image_id' => image_id,
          'level' => '150',
          'evolution' => evolution,
          'phase' => phase,
          'is_locked' => '1',
          'arousal' => { 'is_arousal_weapon' => false },
          'odiant' => { 'is_odiant_weapon' => false }
        },
        'master' => { 'id' => image_id }
      }
    end

    before { ccw_weapon }

    context 'variant resolution' do
      it 'resolves a non-base variant ID to the base weapon record' do
        # Wind variant 1040005500 does NOT exist as a granblue_id in the weapons table.
        # It should be resolved to the Skofnung record via element_variant_ids JSONB.
        expect(Weapon.find_by(granblue_id: '1040005500')).to be_nil

        result = described_class.new(user, { 'list' => [
          weapon_item(game_id: 5001, image_id: '1040005500')
        ] }).import

        expect(result.errors).to be_empty
        expect(result.created.size).to eq(1)

        cw = result.created.first
        expect(cw.weapon_id).to eq(ccw_weapon.id)
        expect(cw.game_id).to eq('5001')
      end

      it 'resolves a variant whose image_id matches the base granblue_id' do
        # Fire variant is 1040005200, which is the same as the base granblue_id.
        # It should still resolve and set the correct element.
        result = described_class.new(user, { 'list' => [
          weapon_item(game_id: 5002, image_id: '1040005200')
        ] }).import

        expect(result.errors).to be_empty
        expect(result.created.first.weapon_id).to eq(ccw_weapon.id)
      end

      it 'returns an error for an image_id that matches no weapon or variant' do
        result = described_class.new(user, { 'list' => [
          weapon_item(game_id: 5003, image_id: '9999999999')
        ] }).import

        expect(result.created).to be_empty
        expect(result.errors.first[:error]).to eq('Weapon not found')
      end
    end

    context 'element assignment' do
      it 'stores the correct element for each variant' do
        result = described_class.new(user, { 'list' => [
          weapon_item(game_id: 6001, image_id: '1040005500'), # Wind = 1
          weapon_item(game_id: 6002, image_id: '1040005300'), # Water = 3
          weapon_item(game_id: 6003, image_id: '1040005700')  # Dark = 5
        ] }).import

        expect(result.errors).to be_empty

        by_game_id = result.created.index_by(&:game_id)
        expect(by_game_id['6001'].element).to eq(1)
        expect(by_game_id['6002'].element).to eq(3)
        expect(by_game_id['6003'].element).to eq(5)
      end

      it 'stores the correct element when variant ID matches base granblue_id' do
        result = described_class.new(user, { 'list' => [
          weapon_item(game_id: 6004, image_id: '1040005200') # Fire = 2
        ] }).import

        expect(result.created.first.element).to eq(2)
      end

      it 'does not set element for non-element-changeable weapons' do
        result = described_class.new(user, { 'list' => [
          weapon_item(game_id: 6005, image_id: standard_weapon.granblue_id)
        ] }).import

        expect(result.created.first.element).to be_nil
      end

      it 'persists element to the database' do
        described_class.new(user, { 'list' => [
          weapon_item(game_id: 6006, image_id: '1040005400') # Earth = 4
        ] }).import

        cw = user.collection_weapons.find_by(game_id: '6006')
        expect(cw.element).to eq(4)
      end
    end

    context 'multiple variants of the same weapon' do
      it 'creates separate collection records for each element variant' do
        data = { 'list' => [
          weapon_item(game_id: 7001, image_id: '1040005500'), # Wind
          weapon_item(game_id: 7002, image_id: '1040005200'), # Fire (base ID)
          weapon_item(game_id: 7003, image_id: '1040005600')  # Light
        ] }

        result = described_class.new(user, data).import

        expect(result.errors).to be_empty
        expect(result.created.size).to eq(3)

        # All three point to the same weapon record
        weapon_ids = result.created.map(&:weapon_id).uniq
        expect(weapon_ids).to eq([ccw_weapon.id])

        # All three have distinct game_ids and elements
        game_ids = result.created.map(&:game_id)
        elements = result.created.map(&:element).sort
        expect(game_ids).to contain_exactly('7001', '7002', '7003')
        expect(elements).to eq([1, 2, 6]) # Wind, Fire, Light
      end

      it 'can re-import the same variants without duplicating (skip by game_id)' do
        data = { 'list' => [
          weapon_item(game_id: 7010, image_id: '1040005500'),
          weapon_item(game_id: 7011, image_id: '1040005300')
        ] }

        first_result = described_class.new(user, data).import
        expect(first_result.created.size).to eq(2)

        second_result = described_class.new(user, data).import
        expect(second_result.created.size).to eq(0)
        expect(second_result.skipped.size).to eq(2)
        expect(second_result.skipped.map { |s| s[:reason] }).to all(eq('Already exists'))
      end
    end

    context 'updating existing element variants' do
      it 'updates uncap_level on existing variant when update_existing is true' do
        # First import at uncap 3
        described_class.new(user, { 'list' => [
          weapon_item(game_id: 8001, image_id: '1040005500', evolution: '3')
        ] }).import

        cw = user.collection_weapons.find_by(game_id: '8001')
        expect(cw.uncap_level).to eq(3)

        # Re-import same game_id at uncap 5
        described_class.new(user, { 'list' => [
          weapon_item(game_id: 8001, image_id: '1040005500', evolution: '5')
        ] }, update_existing: true).import

        cw.reload
        expect(cw.uncap_level).to eq(5)
        expect(cw.element).to eq(1) # Wind element preserved
      end
    end

    context 'mixed import with regular and element-changeable weapons' do
      it 'correctly handles both types in a single import' do
        data = { 'list' => [
          weapon_item(game_id: 9001, image_id: standard_weapon.granblue_id),
          weapon_item(game_id: 9002, image_id: '1040005500'), # Wind Skofnung
          weapon_item(game_id: 9003, image_id: '1040005400')  # Earth Skofnung
        ] }

        result = described_class.new(user, data).import
        expect(result.errors).to be_empty
        expect(result.created.size).to eq(3)

        by_game_id = result.created.index_by(&:game_id)

        # Regular weapon: no element override
        expect(by_game_id['9001'].weapon_id).to eq(standard_weapon.id)
        expect(by_game_id['9001'].element).to be_nil

        # Element variants: correct weapon and element
        expect(by_game_id['9002'].weapon_id).to eq(ccw_weapon.id)
        expect(by_game_id['9002'].element).to eq(1) # Wind
        expect(by_game_id['9003'].weapon_id).to eq(ccw_weapon.id)
        expect(by_game_id['9003'].element).to eq(4) # Earth
      end
    end
  end
end
