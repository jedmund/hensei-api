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

  describe '.export with conflicting versions' do
    it 'raises when two versions share a key but not a name and icon' do
      slot = create(:character_skill, character: create(:character, granblue_id: '3040001000'), kind: 'ability', position: 1)
      create(:character_skill_version, character_skill: slot, ordinal: 2, name_en: 'One', game_icon: '1_1')
      create(:character_skill_version, character_skill: slot, ordinal: 2, name_en: 'Two', game_icon: '1_1')

      expect { described_class.export(path) }.to raise_error(described_class::ConflictError, %r{3040001000/1/ability/1/2})
      expect(File.exist?(path)).to be(false)
    end

    it 'collapses identical duplicates into one entry' do
      slot = create(:character_skill, character: create(:character, granblue_id: '3040001000'), kind: 'ability', position: 1)
      2.times { create(:character_skill_version, character_skill: slot, ordinal: 2, name_en: 'Same', game_icon: '1_1') }

      expect(described_class.export(path)).to eq(1)
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

  describe '.icon_for' do
    let(:entries) do
      [
        { granblue_id: '3030003000', style: 1, kind: 'ability', position: 1, ordinal: 1, name_en: 'Flamebound', game_icon: '4_1' },
        { granblue_id: '3030003000', style: 1, kind: 'ability', position: 1, ordinal: 2, name_en: 'Flamebound', game_icon: '4_1' },
        { granblue_id: '3030003000', style: 1, kind: 'ability', position: 2, ordinal: 1, name_en: 'Split', game_icon: '5_1' },
        { granblue_id: '3030003000', style: 1, kind: 'ability', position: 2, ordinal: 2, name_en: 'Split', game_icon: '6_1' },
        { granblue_id: '3030003000', style: 1, kind: 'ability', position: 2, ordinal: 3, name_en: 'Exact', game_icon: '7_1' }
      ]
    end

    before { File.write(path, JSON.generate(entries)) }

    def icon(position:, ordinal:, name_en:)
      key = { granblue_id: '3030003000', style: 1, kind: 'ability', position: position, ordinal: ordinal }
      described_class.icon_for(key, name_en: name_en, path: path)
    end

    it 'takes the exact entry when it names the same ability' do
      expect(icon(position: 2, ordinal: 3, name_en: 'Exact')).to eq('7_1')
    end

    it 'prefers the exact entry over the slot fallback' do
      expect(icon(position: 2, ordinal: 1, name_en: 'Split')).to eq('5_1')
    end

    it 'falls back to the slot entries with the same name on a renumbered ordinal' do
      expect(icon(position: 1, ordinal: 3, name_en: 'Flamebound')).to eq('4_1')
    end

    it 'gives nothing when the slot entries with that name disagree' do
      expect(icon(position: 2, ordinal: 4, name_en: 'Split')).to be_nil
    end

    it 'gives nothing when no entry has the name' do
      expect(icon(position: 1, ordinal: 1, name_en: 'Something Else')).to be_nil
    end
  end
end
