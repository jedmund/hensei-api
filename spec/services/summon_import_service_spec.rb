# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonImportService, type: :service do
  let(:user) { create(:user) }

  # Create summons with specific granblue_ids matching the game data
  let(:standard_summon) do
    Summon.find_by(granblue_id: '2040035000') ||
      create(:summon, granblue_id: '2040035000', name_en: 'Celeste')
  end

  let(:flb_summon) do
    Summon.find_by(granblue_id: '2040445000') ||
      create(:summon, granblue_id: '2040445000', name_en: 'Typhon')
  end

  let(:ulb_summon) do
    Summon.find_by(granblue_id: '2040379000') ||
      create(:summon, granblue_id: '2040379000', name_en: 'Gorilla')
  end

  let(:transcendable_summon) do
    Summon.find_by(granblue_id: '2040100000') ||
      create(:summon, :transcendable, granblue_id: '2040100000', name_en: 'Bahamut')
  end

  before do
    standard_summon
    flb_summon
    ulb_summon
    transcendable_summon
  end

  describe '#import' do
    context 'with valid game data' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 1_500_667_184,
                'image_id' => '2040035000',
                'level' => '1',
                'evolution' => '0',
                'phase' => '0'
              },
              'master' => {
                'id' => 2_040_035_000,
                'rarity' => '4'
              }
            }
          ]
        }
      end

      it 'creates a collection summon' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.errors).to be_empty
      end

      it 'sets the correct game_id' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.game_id).to eq('1500667184')
      end

      it 'sets the correct uncap_level from evolution' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.uncap_level).to eq(0)
      end

      it 'associates the correct summon via granblue_id' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.summon.granblue_id).to eq('2040035000')
      end
    end

    context 'with FLB summon (evolution 4)' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 1_499_006_961,
                'image_id' => '2040445000',
                'level' => '150',
                'evolution' => '4',
                'phase' => '0'
              },
              'master' => {
                'id' => 2_040_445_000,
                'rarity' => '4'
              }
            }
          ]
        }
      end

      it 'sets uncap_level to 4' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.uncap_level).to eq(4)
      end
    end

    context 'with ULB summon (evolution 5)' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 1_494_986_603,
                'image_id' => '2040379000',
                'level' => '200',
                'evolution' => '5',
                'phase' => '0'
              },
              'master' => {
                'id' => 2_040_379_000,
                'rarity' => '4'
              }
            }
          ]
        }
      end

      it 'sets uncap_level to 5' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.uncap_level).to eq(5)
      end
    end

    context 'with transcendence data (evolution 6, phase 5)' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 1_088_016_859,
                'image_id' => '2040100000_04',
                'level' => '250',
                'evolution' => '6',
                'phase' => '5'
              },
              'master' => {
                'id' => 2_040_100_000,
                'rarity' => '4'
              }
            }
          ]
        }
      end

      it 'clamps uncap_level to 5 even when evolution is 6' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.uncap_level).to eq(5)
      end

      it 'sets transcendence_step from phase' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.transcendence_step).to eq(5)
      end
    end

    context 'with duplicate game_id' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 9_999_9999,
                'image_id' => '2040035000',
                'evolution' => '3',
                'phase' => '0'
              },
              'master' => { 'id' => 2_040_035_000 }
            }
          ]
        }
      end

      before do
        create(:collection_summon, user: user, summon: standard_summon, game_id: '99999999')
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
                  'id' => 9_999_9999,
                  'image_id' => '2040035000',
                  'evolution' => '5',
                  'phase' => '0'
                },
                'master' => { 'id' => 2_040_035_000 }
              }
            ]
          }
        end

        it 'updates the existing summon' do
          service = described_class.new(user, game_data_updated, update_existing: true)
          result = service.import

          expect(result.success?).to be true
          expect(result.created.size).to eq(0)
          expect(result.updated.size).to eq(1)
          expect(result.updated.first.uncap_level).to eq(5)
        end
      end
    end

    context 'with unknown summon' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 12_345,
                'image_id' => '9999999999',
                'evolution' => '3',
                'phase' => '0'
              },
              'master' => { 'id' => 9_999_999_999 }
            }
          ]
        }
      end

      it 'records an error for the unknown summon' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:error]).to eq('Summon not found')
      end
    end

    context 'with multiple summons' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 1_111_1111,
                'image_id' => '2040035000',
                'evolution' => '0',
                'phase' => '0'
              },
              'master' => { 'id' => 2_040_035_000 }
            },
            {
              'param' => {
                'id' => 2_222_2222,
                'image_id' => '2040445000',
                'evolution' => '4',
                'phase' => '0'
              },
              'master' => { 'id' => 2_040_445_000 }
            }
          ]
        }
      end

      it 'imports all summons' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(2)
      end

      it 'associates correct summons' do
        service = described_class.new(user, game_data)
        result = service.import

        summons = result.created.sort_by(&:game_id)
        expect(summons[0].summon.granblue_id).to eq('2040035000')
        expect(summons[1].summon.granblue_id).to eq('2040445000')
      end
    end

    context 'with empty data' do
      let(:game_data) { { 'list' => [] } }

      it 'returns an error' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be false
        expect(result.errors).to include('No summon items found in data')
      end
    end

    context 'with array format data' do
      let(:game_data) do
        [
          {
            'param' => {
              'id' => 7_777_7777,
              'image_id' => '2040035000',
              'evolution' => '3',
              'phase' => '0'
            },
            'master' => { 'id' => 2_040_035_000 }
          }
        ]
      end

      it 'handles array format correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.created.first.uncap_level).to eq(3)
      end
    end

    context 'with image_id containing suffix' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 8_888_8888,
                'image_id' => '2040100000_04',
                'evolution' => '6',
                'phase' => '5'
              },
              'master' => { 'id' => 2_040_100_000 }
            }
          ]
        }
      end

      it 'uses master.id when image_id has suffix' do
        service = described_class.new(user, game_data)
        result = service.import

        # Uses master.id since image_id with _04 suffix won't match
        expect(result.created.first.summon.granblue_id).to eq('2040100000')
      end
    end

    context 'with max values' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 6_666_6666,
                'image_id' => '2040100000',
                'evolution' => '10',
                'phase' => '15'
              },
              'master' => { 'id' => 2_040_100_000 }
            }
          ]
        }
      end

      it 'clamps uncap_level to max 5' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.uncap_level).to eq(5)
      end

      it 'clamps transcendence_step to max 10' do
        service = described_class.new(user, game_data)
        result = service.import

        summon = result.created.first
        expect(summon.transcendence_step).to eq(10)
      end
    end
  end

  describe 'edge cases' do
    context 'with nil param values' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 5_555_5555,
                'image_id' => '2040035000',
                'evolution' => nil,
                'phase' => nil
              },
              'master' => { 'id' => 2_040_035_000 }
            }
          ]
        }
      end

      it 'handles nil values gracefully (defaults to 0)' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.uncap_level).to eq(0)
        expect(result.created.first.transcendence_step).to eq(0)
      end
    end

    context 'with string evolution values' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 4_444_4444,
                'image_id' => '2040035000',
                'evolution' => '4',
                'phase' => '0'
              },
              'master' => { 'id' => 2_040_035_000 }
            }
          ]
        }
      end

      it 'handles string evolution values' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.uncap_level).to eq(4)
      end
    end

    context 'with master.id fallback' do
      let(:game_data) do
        {
          'list' => [
            {
              'param' => {
                'id' => 3_333_3333,
                'evolution' => '3',
                'phase' => '0'
              },
              'master' => {
                'id' => 2_040_035_000
              }
            }
          ]
        }
      end

      it 'uses master.id when param.image_id is missing' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.summon.granblue_id).to eq('2040035000')
      end
    end
  end
end
