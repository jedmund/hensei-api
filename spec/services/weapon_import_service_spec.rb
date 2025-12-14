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

      it 'sets uncap_level to 5 for transcended weapons' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.uncap_level).to eq(5)
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
                      'skill_id' => 1,
                      'effect_value' => '7',
                      'show_value' => '7%'
                    },
                    {
                      'skill_id' => 2,
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
        expect(weapon.ax_modifier1).to eq(1)
        expect(weapon.ax_strength1).to eq(7.0)
      end

      it 'parses second AX skill with underscore format' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.ax_modifier2).to eq(2)
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
                      'skill_id' => 3,
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
        expect(weapon.ax_modifier1).to eq(3)
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

      it 'clamps uncap_level to max 5' do
        service = described_class.new(user, game_data)
        result = service.import

        weapon = result.created.first
        expect(weapon.uncap_level).to eq(5)
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
end
