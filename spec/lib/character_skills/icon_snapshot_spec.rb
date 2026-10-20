# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::IconSnapshot do
  let(:path) { Rails.root.join('tmp', "icon-snapshot-#{SecureRandom.hex(4)}.json") }

  before { described_class.reset! }

  after do
    FileUtils.rm_f(path)
    described_class.reset!
  end

  describe '.export' do
    let(:base) { create(:character, granblue_id: '3040377000') }

    before do
      create(:character, granblue_id: '3040377000', style_swap: true)
      second = create(:character_skill, character: base, kind: 'ability', position: 2)
      first = create(:character_skill, character: base, kind: 'ability', position: 1)
      create(:character_skill_version, character_skill: second, ordinal: 1, name_en: 'Second', game_icon: '2_1')
      create(:character_skill_version, character_skill: first, ordinal: 2, name_en: 'First+', game_icon: '1_2')
      create(:character_skill_version, character_skill: first, ordinal: 1, name_en: 'First', game_icon: '1_1')
      create(:character_skill_version, character_skill: first, ordinal: 3, name_en: 'No icon', game_icon: nil)
    end

    it 'writes one sorted entry per version with a game icon, one per line' do
      expect(described_class.export(path)).to eq(3)

      lines = File.read(path).lines
      entries = JSON.parse(File.read(path))
      aggregate_failures do
        expect(lines.size).to eq(5)
        expect(entries.map { |e| [e['position'], e['ordinal']] }).to eq([[1, 1], [1, 2], [2, 1]])
        expect(entries.first).to eq(
          'granblue_id' => '3040377000', 'style' => 1, 'kind' => 'ability', 'position' => 1, 'ordinal' => 1,
          'name_en' => 'First', 'game_icon' => '1_1'
        )
      end
    end
  end

  describe '.load' do
    it 'indexes entries by granblue_id, style, kind, position and ordinal' do
      File.write(path, JSON.generate([{ granblue_id: '3040377000', style: 2, kind: 'ability', position: 1, ordinal: 1,
                                        name_en: 'Jinx', game_icon: '2559_3' }]))

      expect(described_class.load(path)).to eq(['3040377000', 2, 'ability', 1, 1] => { name_en: 'Jinx', game_icon: '2559_3' })
      expect(described_class.lookup(granblue_id: '3040377000', style: 2, kind: 'ability', position: 1, ordinal: 1, path: path))
        .to eq(name_en: 'Jinx', game_icon: '2559_3')
    end

    it 'is empty when the file is absent' do
      expect(described_class.load(path)).to eq({})
    end
  end
end
