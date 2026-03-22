# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArtifactImportService, type: :service do
  let(:user) { create(:user) }

  # Create artifacts with specific granblue_ids matching the game data
  let(:standard_artifact) do
    Artifact.find_by(granblue_id: '301070101') ||
      create(:artifact, granblue_id: '301070101', name_en: 'Ominous Bangle', proficiency: :melee)
  end
  let(:standard_artifact_2) do
    Artifact.find_by(granblue_id: '301090101') ||
      create(:artifact, granblue_id: '301090101', name_en: 'Ominous Whistle', proficiency: :gun)
  end
  let(:quirk_artifact) do
    Artifact.find_by(granblue_id: '401110401') ||
      create(:artifact, :quirk, granblue_id: '401110401', name_en: 'Fantosmik Fengtooth')
  end

  # Create artifact skills for the skill lookups
  before do
    # Create artifacts
    standard_artifact
    standard_artifact_2
    quirk_artifact

    # Group I skills
    ArtifactSkill.find_by(skill_group: 1, modifier: 2) ||
      create(:artifact_skill, :group_i, modifier: 2, name_en: 'HP', name_jp: 'HP', base_values: [660, 720, 780, 840, 900])
    ArtifactSkill.find_by(skill_group: 1, modifier: 5) ||
      create(:artifact_skill, :group_i, modifier: 5, name_en: 'Elemental ATK', name_jp: '自属性攻撃力', base_values: [8.8, 9.6, 10.4, 11.2, 12.0])
    ArtifactSkill.find_by(skill_group: 1, modifier: 11) ||
      create(:artifact_skill, :group_i, modifier: 11, name_en: 'Dodge Rate', name_jp: '回避率', base_values: [4.4, 4.8, 5.2, 5.6, 6.0])

    # Group II skills
    ArtifactSkill.find_by(skill_group: 2, modifier: 2) ||
      create(:artifact_skill, :group_ii, modifier: 2, name_en: 'Skill DMG Cap', name_jp: 'アビダメ上限', base_values: [8.8, 9.6, 10.4, 11.2, 12.0])
    ArtifactSkill.find_by(skill_group: 2, modifier: 8) ||
      create(:artifact_skill, :group_ii, modifier: 8, name_en: 'C.A. DMG cap boost tradeoff', name_jp: '奥義ダメ上限UP', base_values: [13.2, 14.4, 15.6, 16.8, 18.0])

    # Group III skills
    ArtifactSkill.find_by(skill_group: 3, modifier: 5) ||
      create(:artifact_skill, :group_iii, modifier: 5, name_en: 'Switch amplified', name_jp: 'バトル登場時', base_values: [3, 6, 9, 12, 15])
    ArtifactSkill.find_by(skill_group: 3, modifier: 25) ||
      create(:artifact_skill, :group_iii, modifier: 25, name_en: 'Armored', name_jp: 'ブロック効果', base_values: [5, 10, 15, 20, 25])

    # Clear the cache so new skills are picked up
    ArtifactSkill.clear_cache!
  end

  after do
    ArtifactSkill.clear_cache!
  end

  describe '#import' do
    context 'with valid game data' do
      let(:game_data) do
        {
          'list' => [
            {
              'artifact_id' => 301_070_101,
              'id' => 8_138_020,
              'level' => '1',
              'kind' => '7',
              'attribute' => '5',
              'skill1_info' => { 'name' => 'Dodge Rate', 'skill_quality' => 1, 'level' => 1 },
              'skill2_info' => { 'name' => 'HP', 'skill_quality' => 5, 'level' => 1 },
              'skill3_info' => { 'name' => 'C.A. DMG cap boost tradeoff', 'skill_quality' => 1, 'level' => 1 },
              'skill4_info' => { 'name' => 'Switch amplified', 'skill_quality' => 1, 'level' => 1 }
            }
          ]
        }
      end

      it 'creates a collection artifact' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
        expect(result.errors).to be_empty
      end

      it 'sets the correct game_id' do
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.game_id).to eq('8138020')
      end

      it 'maps element correctly' do
        # attribute 5 = Light in game, which maps to our light (6)
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.element).to eq('light')
      end

      it 'parses skill1 correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.skill1['modifier']).to eq(11)
        expect(artifact.skill1['quality']).to eq(1)
        expect(artifact.skill1['level']).to eq(1)
      end

      it 'parses skill2 with max quality correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.skill2['modifier']).to eq(2)
        expect(artifact.skill2['quality']).to eq(5)
      end

      it 'parses skill3 (group II) correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.skill3['modifier']).to eq(8)
        expect(artifact.skill3['quality']).to eq(1)
      end

      it 'parses skill4 (group III) correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.skill4['modifier']).to eq(5)
        expect(artifact.skill4['quality']).to eq(1)
      end
    end

    context 'with duplicate game_id' do
      let(:game_data) do
        {
          'list' => [
            {
              'artifact_id' => 301_070_101,
              'id' => 8_138_020,
              'level' => '1',
              'kind' => '7',
              'attribute' => '5',
              'skill1_info' => { 'name' => 'Dodge Rate', 'skill_quality' => 1, 'level' => 1 },
              'skill2_info' => { 'name' => 'HP', 'skill_quality' => 5, 'level' => 1 },
              'skill3_info' => { 'name' => 'C.A. DMG cap boost tradeoff', 'skill_quality' => 1, 'level' => 1 },
              'skill4_info' => { 'name' => 'Switch amplified', 'skill_quality' => 1, 'level' => 1 }
            }
          ]
        }
      end

      before do
        create(:collection_artifact, user: user, artifact: standard_artifact, game_id: '8138020')
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
        it 'updates the existing artifact' do
          service = described_class.new(user, game_data, update_existing: true)
          result = service.import

          expect(result.success?).to be true
          expect(result.created.size).to eq(0)
          expect(result.updated.size).to eq(1)
        end
      end
    end

    context 'with quirk artifact' do
      let(:game_data) do
        {
          'list' => [
            {
              'artifact_id' => 401_110_401,
              'rarity' => '4',
              'id' => 7_977_596,
              'level' => '1',
              'kind' => '8',
              'attribute' => '6',
              'skill1_info' => { 'name' => 'Unknown Skill 1', 'skill_quality' => 1, 'level' => 1 },
              'skill2_info' => { 'name' => 'Unknown Skill 2', 'skill_quality' => 1, 'level' => 1 },
              'skill3_info' => { 'name' => 'Unknown Skill 3', 'skill_quality' => 1, 'level' => 1 },
              'skill4_info' => { 'name' => 'Unknown Skill 4', 'skill_quality' => 1, 'level' => 1 }
            }
          ]
        }
      end

      it 'creates the quirk artifact with proficiency' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        artifact = result.created.first
        expect(artifact.artifact.quirk?).to be true
        expect(artifact.proficiency).to eq('bow') # game kind 8 = bow
      end

      it 'stores empty skills for unknown skill names' do
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.skill1).to eq({})
        expect(artifact.skill2).to eq({})
        expect(artifact.skill3).to eq({})
        expect(artifact.skill4).to eq({})
      end

      it 'maps element correctly for quirk artifacts' do
        # attribute 6 = Dark in game, which maps to our dark (5)
        service = described_class.new(user, game_data)
        result = service.import

        artifact = result.created.first
        expect(artifact.element).to eq('dark')
      end
    end

    context 'with unknown artifact_id' do
      let(:game_data) do
        {
          'list' => [
            {
              'artifact_id' => 999_999_999,
              'id' => 1234,
              'level' => '1',
              'kind' => '1',
              'attribute' => '1',
              'skill1_info' => {},
              'skill2_info' => {},
              'skill3_info' => {},
              'skill4_info' => {}
            }
          ]
        }
      end

      it 'records an error for the unknown artifact' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:error]).to eq('Artifact not found')
      end
    end

    context 'with multiple artifacts' do
      let(:game_data) do
        {
          'list' => [
            {
              'artifact_id' => 301_070_101,
              'id' => 8_138_020,
              'level' => '1',
              'kind' => '7',
              'attribute' => '5',
              'skill1_info' => { 'name' => 'Dodge Rate', 'skill_quality' => 1, 'level' => 1 },
              'skill2_info' => { 'name' => 'HP', 'skill_quality' => 5, 'level' => 1 },
              'skill3_info' => { 'name' => 'C.A. DMG cap boost tradeoff', 'skill_quality' => 1, 'level' => 1 },
              'skill4_info' => { 'name' => 'Switch amplified', 'skill_quality' => 1, 'level' => 1 }
            },
            {
              'artifact_id' => 301_090_101,
              'id' => 8_061_615,
              'level' => '1',
              'kind' => '9',
              'attribute' => '6',
              'skill1_info' => { 'name' => 'Elemental ATK', 'skill_quality' => 2, 'level' => 1 },
              'skill2_info' => { 'name' => 'HP', 'skill_quality' => 1, 'level' => 1 },
              'skill3_info' => { 'name' => 'Skill DMG Cap', 'skill_quality' => 1, 'level' => 1 },
              'skill4_info' => { 'name' => 'Armored', 'skill_quality' => 1, 'level' => 1 }
            }
          ]
        }
      end

      it 'imports all artifacts' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(2)
      end

      it 'associates correct artifacts' do
        service = described_class.new(user, game_data)
        result = service.import

        artifacts = result.created.sort_by(&:game_id)
        expect(artifacts[0].artifact.name_en).to eq('Ominous Whistle')
        expect(artifacts[1].artifact.name_en).to eq('Ominous Bangle')
      end
    end

    context 'with empty data' do
      let(:game_data) { { 'list' => [] } }

      it 'returns an error' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be false
        expect(result.errors).to include('No artifact items found in data')
      end
    end

    context 'with array format data' do
      let(:game_data) do
        [
          {
            'artifact_id' => 301_070_101,
            'id' => 8_138_020,
            'level' => '1',
            'kind' => '7',
            'attribute' => '5',
            'skill1_info' => { 'name' => 'Dodge Rate', 'skill_quality' => 1, 'level' => 1 },
            'skill2_info' => { 'name' => 'HP', 'skill_quality' => 5, 'level' => 1 },
            'skill3_info' => { 'name' => 'C.A. DMG cap boost tradeoff', 'skill_quality' => 1, 'level' => 1 },
            'skill4_info' => { 'name' => 'Switch amplified', 'skill_quality' => 1, 'level' => 1 }
          }
        ]
      end

      it 'handles array format correctly' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        expect(result.created.size).to eq(1)
      end
    end

    context 'with Japanese skill names' do
      let(:game_data) do
        {
          'list' => [
            {
              'artifact_id' => 301_070_101,
              'id' => 8_138_020,
              'level' => '1',
              'kind' => '7',
              'attribute' => '5',
              'skill1_info' => { 'name' => '回避率', 'skill_quality' => 1, 'level' => 1 },
              'skill2_info' => {},
              'skill3_info' => {},
              'skill4_info' => {}
            }
          ]
        }
      end

      it 'matches skills by Japanese name' do
        service = described_class.new(user, game_data)
        result = service.import

        expect(result.success?).to be true
        artifact = result.created.first
        expect(artifact.skill1['modifier']).to eq(11) # Dodge Rate
        expect(artifact.skill1['quality']).to eq(1)
      end
    end
  end

  describe 'element mapping' do
    # Game: 1=Fire, 2=Water, 3=Earth, 4=Wind, 5=Light, 6=Dark
    # Ours: wind=1, fire=2, water=3, earth=4, dark=5, light=6
    {
      '1' => 'fire',
      '2' => 'water',
      '3' => 'earth',
      '4' => 'wind',
      '5' => 'light',
      '6' => 'dark'
    }.each do |game_attr, expected_element|
      it "maps game attribute #{game_attr} to #{expected_element}" do
        game_data = {
          'list' => [
            {
              'artifact_id' => 301_070_101,
              'id' => 1234,
              'level' => '1',
              'kind' => '7',
              'attribute' => game_attr,
              'skill1_info' => {},
              'skill2_info' => {},
              'skill3_info' => {},
              'skill4_info' => {}
            }
          ]
        }

        service = described_class.new(user, game_data)
        result = service.import

        expect(result.created.first.element).to eq(expected_element)
      end
    end
  end

  describe 'skill quality storage' do
    it 'stores quality 1 correctly' do
      game_data = {
        'list' => [
          {
            'artifact_id' => 301_070_101,
            'id' => 1234,
            'level' => '1',
            'kind' => '7',
            'attribute' => '1',
            'skill1_info' => { 'name' => 'Dodge Rate', 'skill_quality' => 1, 'level' => 1 },
            'skill2_info' => {},
            'skill3_info' => {},
            'skill4_info' => {}
          }
        ]
      }

      service = described_class.new(user, game_data)
      result = service.import

      expect(result.created.first.skill1['quality']).to eq(1)
    end

    it 'stores quality 5 correctly' do
      game_data = {
        'list' => [
          {
            'artifact_id' => 301_070_101,
            'id' => 1234,
            'level' => '1',
            'kind' => '7',
            'attribute' => '1',
            'skill1_info' => { 'name' => 'Dodge Rate', 'skill_quality' => 5, 'level' => 1 },
            'skill2_info' => {},
            'skill3_info' => {},
            'skill4_info' => {}
          }
        ]
      }

      service = described_class.new(user, game_data)
      result = service.import

      expect(result.created.first.skill1['quality']).to eq(5)
    end
  end
end
