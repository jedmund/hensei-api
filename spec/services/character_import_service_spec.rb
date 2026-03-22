# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterImportService, type: :service do
  let(:user) { create(:user) }

  # Create character awakening first (required by model's before_save callback)
  let!(:awakening_balanced) do
    Awakening.find_by(slug: 'character-balanced', object_type: 'Character') ||
      create(:awakening, :for_character, slug: 'character-balanced', name_en: 'Balanced')
  end

  # Create characters with specific granblue_ids matching the game data
  # Use unique IDs that won't conflict with seeded data
  let(:standard_character) do
    Character.find_by(granblue_id: '3040171000') ||
      create(:character, granblue_id: '3040171000', name_en: 'Hallessena')
  end

  let(:flb_character) do
    Character.find_by(granblue_id: '3040167000') ||
      create(:character, granblue_id: '3040167000', name_en: 'Zeta')
  end

  let(:transcendable_character) do
    Character.find_by(granblue_id: '3040036000') ||
      create(:character, :transcendable, granblue_id: '3040036000', name_en: 'Siegfried')
  end

  let(:another_character) do
    Character.find_by(granblue_id: '3040212000') ||
      create(:character, granblue_id: '3040212000', name_en: 'Narmaya (Summer)')
  end

  before do
    standard_character
    flb_character
    transcendable_character
    another_character
  end

  describe '#import' do
    context 'with valid game data' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => {
                'id' => '3040171000',
                'max_evolution_level' => 4
              },
              'param' => {
                'id' => 129_355_003,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 1
              }
            }
          ]
        }
      end

      it 'creates a collection character' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.errors).to be_empty
      end

      it 'sets the correct uncap_level from evolution' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.uncap_level).to eq(4)
      end

      it 'associates the correct character via granblue_id' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.character.granblue_id).to eq('3040171000')
      end

      it 'sets awakening_level from arousal_level' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.awakening_level).to eq(1)
      end
    end

    context 'with FLB character (evolution 5)' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => {
                'id' => '3040167000',
                'max_evolution_level' => 5
              },
              'param' => {
                'id' => 128_935_603,
                'evolution' => '5',
                'phase' => '0',
                'arousal_level' => 9
              }
            }
          ]
        }
      end

      it 'sets uncap_level to 5' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.uncap_level).to eq(5)
      end

      it 'sets awakening_level from arousal_level' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.awakening_level).to eq(9)
      end
    end

    context 'with transcendence data (evolution 6, phase 5)' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => {
                'id' => '3040036000',
                'max_evolution_level' => 6
              },
              'param' => {
                'id' => 128_343_789,
                'evolution' => '6',
                'phase' => '5',
                'arousal_level' => 10
              }
            }
          ]
        }
      end

      it 'sets uncap_level to 6 for transcended characters' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.uncap_level).to eq(6)
      end

      it 'sets transcendence_step from phase' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.transcendence_step).to eq(5)
      end

      it 'sets max awakening_level' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.awakening_level).to eq(10)
      end
    end

    context 'with duplicate character (unique per user)' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => {
                'id' => '3040171000'
              },
              'param' => {
                'id' => 999_999_999,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 5
              }
            }
          ]
        }
      end

      before do
        create(:collection_character, user: user, character: standard_character)
      end

      it 'skips the duplicate based on character_id (not game_id)' do
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
                'master' => {
                  'id' => '3040171000'
                },
                'param' => {
                  'id' => 999_999_999,
                  'evolution' => '5',
                  'phase' => '0',
                  'arousal_level' => 10
                }
              }
            ]
          }
        end

        it 'updates the existing character' do
          service = described_class.new(user, game_data_updated, update_existing: true)
          result = service.import

          expect(result.success?).to be true
          expect(result.created.size).to eq(0)
          expect(result.updated.size).to eq(1)
          expect(result.updated.first.uncap_level).to eq(5)
          expect(result.updated.first.awakening_level).to eq(10)
        end
      end
    end

    context 'with unknown character' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => {
                'id' => '9999999999'
              },
              'param' => {
                'id' => 12_345,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 1
              }
            }
          ]
        }
      end

      it 'records an error for the unknown character' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:error]).to eq('Character not found')
      end
    end

    context 'with multiple characters' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 111_111_111,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 1
              }
            },
            {
              'master' => { 'id' => '3040212000' },
              'param' => {
                'id' => 222_222_222,
                'evolution' => '5',
                'phase' => '0',
                'arousal_level' => 7
              }
            }
          ]
        }
      end

      it 'imports all characters' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(2)
      end

      it 'associates correct characters' do
        service = described_class.new(user, game_data)
        result = service.import

        granblue_ids = result.created.map { |c| c.character.granblue_id }.sort
        expect(granblue_ids).to eq(%w[3040171000 3040212000])
      end
    end

    context 'with empty data' do
      let(:game_data) { { 'list' => [] } }

      it 'returns an error' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be false
        expect(result.errors).to include('No character items found in data')
      end
    end

    context 'with array format data' do
      let(:game_data) do
        [
          {
            'master' => { 'id' => '3040171000' },
            'param' => {
              'id' => 777_777_777,
              'evolution' => '4',
              'phase' => '0',
              'arousal_level' => 5
            }
          }
        ]
      end

      it 'handles array format correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.created.first.awakening_level).to eq(5)
      end
    end

    context 'with max values' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040036000' },
              'param' => {
                'id' => 888_888_888,
                'evolution' => '10',
                'phase' => '15',
                'arousal_level' => 99
              }
            }
          ]
        }
      end

      it 'sets uncap_level to 6 for transcended characters' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.uncap_level).to eq(6)
      end

      it 'clamps transcendence_step to max 10' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.transcendence_step).to eq(10)
      end

      it 'clamps awakening_level to max 10' do
        service = described_class.new(user, game_data)
        result = service.import

        character = result.created.first
        expect(character.awakening_level).to eq(10)
      end
    end
  end

  describe 'perpetuity ring' do
    context 'when has_npcaugment_constant is true' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 111_111_111,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 10,
                'has_npcaugment_constant' => true
              }
            }
          ]
        }
      end

      it 'sets perpetuity to true' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.created.first.perpetuity).to be true
      end
    end

    context 'when has_npcaugment_constant is false' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 111_111_111,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 10,
                'has_npcaugment_constant' => false
              }
            }
          ]
        }
      end

      it 'does not set perpetuity' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.created.first.perpetuity).to be false
      end
    end

    context 'when updating an existing ringed character with unreliable data' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 111_111_111,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 10,
                'has_npcaugment_constant' => false
              }
            }
          ]
        }
      end

      before do
        create(:collection_character, user: user, character: standard_character, perpetuity: true)
      end

      it 'preserves existing perpetuity true value' do
        service = described_class.new(user, game_data, update_existing: true)
        result = service.import

        expect(result.updated.first.perpetuity).to be true
      end
    end
  end

  describe 'edge cases' do
    context 'with nil arousal_level' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 555_555_555,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => nil
              }
            }
          ]
        }
      end

      it 'defaults awakening_level to 1' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.awakening_level).to eq(1)
      end
    end

    context 'with arousal_level 0' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 444_444_444,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 0
              }
            }
          ]
        }
      end

      it 'defaults awakening_level to 1' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.awakening_level).to eq(1)
      end
    end

    context 'with string evolution values' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 333_333_333,
                'evolution' => '5',
                'phase' => '0',
                'arousal_level' => '7'
              }
            }
          ]
        }
      end

      it 'handles string values correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.uncap_level).to eq(5)
        expect(result.created.first.awakening_level).to eq(7)
      end
    end

    context 'with missing param fields' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 222_222_222
              }
            }
          ]
        }
      end

      it 'handles missing fields gracefully (defaults to 0/1)' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        character = result.created.first
        expect(character.uncap_level).to eq(0)
        expect(character.transcendence_step).to eq(0)
        expect(character.awakening_level).to eq(1)
      end
    end

    context 'assigns default awakening via model callback' do
      let(:game_data) do
        {
          'list' => [
            {
              'master' => { 'id' => '3040171000' },
              'param' => {
                'id' => 111_111_111,
                'evolution' => '4',
                'phase' => '0',
                'arousal_level' => 5
              }
            }
          ]
        }
      end

      it 'has default awakening set by model' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.first.awakening).to eq(awakening_balanced)
      end
    end
  end
end
