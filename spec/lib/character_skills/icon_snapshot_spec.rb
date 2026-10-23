# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::IconSnapshot do
  def stored_text = Source.read(nil, :icon_snapshot, key: described_class::KEY)

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

    it 'stores one sorted entry per version with a game icon, one per line, as the shared row' do
      expect(described_class.export).to eq(3)

      lines = stored_text.lines
      entries = JSON.parse(stored_text)
      aggregate_failures do
        expect(lines.size).to eq(5)
        expect(entries.map { |e| [e['position'], e['ordinal']] }).to eq([[1, 1], [1, 2], [2, 1]])
        expect(entries.first).to eq(
          'granblue_id' => '3040377000', 'style' => 1, 'kind' => 'ability', 'position' => 1, 'ordinal' => 1,
          'name_en' => 'First', 'game_icon' => '1_1'
        )
        expect(described_class.sha256).to eq(Digest::SHA256.hexdigest(stored_text))
      end
    end

    it 'is read back at once' do
      expect(described_class.load).to eq({})
      described_class.export
      expect(described_class.lookup(granblue_id: '3040377000', style: 1, kind: 'ability', position: 2, ordinal: 1))
        .to eq(name_en: 'Second', game_icon: '2_1')
    end
  end

  describe '.export with conflicting versions' do
    it 'raises when two versions share a key but not a name and icon' do
      slot = create(:character_skill, character: create(:character, granblue_id: '3040001000'), kind: 'ability', position: 1)
      create(:character_skill_version, character_skill: slot, ordinal: 2, name_en: 'One', game_icon: '1_1')
      create(:character_skill_version, character_skill: slot, ordinal: 2, name_en: 'Two', game_icon: '1_1')

      expect { described_class.export }.to raise_error(described_class::ConflictError, %r{3040001000/1/ability/1/2})
      expect(stored_text).to be_nil
    end

    it 'collapses identical duplicates into one entry' do
      slot = create(:character_skill, character: create(:character, granblue_id: '3040001000'), kind: 'ability', position: 1)
      2.times { create(:character_skill_version, character_skill: slot, ordinal: 2, name_en: 'Same', game_icon: '1_1') }

      expect(described_class.export).to eq(1)
    end
  end

  describe '.load' do
    it 'indexes entries by granblue_id, style, kind, position and ordinal' do
      put_icon_snapshot([{ granblue_id: '3040377000', style: 2, kind: 'ability', position: 1, ordinal: 1,
                           name_en: 'Jinx', game_icon: '2559_3' }])

      expect(described_class.load).to eq(['3040377000', 2, 'ability', 1, 1] => { name_en: 'Jinx', game_icon: '2559_3' })
      expect(described_class.lookup(granblue_id: '3040377000', style: 2, kind: 'ability', position: 1, ordinal: 1))
        .to eq(name_en: 'Jinx', game_icon: '2559_3')
    end

    it 'is empty when nothing is stored' do
      expect(described_class.load).to eq({})
      expect(described_class.sha256).to be_nil
    end
  end

  describe '.refresh!' do
    let(:entry) { { granblue_id: '3040377000', style: 1, kind: 'ability', position: 1, ordinal: 1, name_en: 'Jinx' } }
    let(:key) { entry.slice(:granblue_id, :style, :kind, :position, :ordinal) }

    it 'reloads the index when another process stored a new snapshot, and returns its sha256' do
      put_icon_snapshot([entry.merge(game_icon: '1_1')])
      expect(described_class.icon_for(key, name_en: 'Jinx')).to eq('1_1')

      # Written past this process's cache, as another process's export would be.
      Source.put(nil, :icon_snapshot, JSON.generate([entry.merge(game_icon: '2_1')]), key: described_class::KEY)
      expect(described_class.icon_for(key, name_en: 'Jinx')).to eq('1_1')

      expect(described_class.refresh!).to eq(described_class.sha256)
      expect(described_class.icon_for(key, name_en: 'Jinx')).to eq('2_1')
    end

    it 'gives the fingerprint the sha256 of the snapshot it loaded' do
      put_icon_snapshot([entry.merge(game_icon: '1_1')])
      expect(CharacterSkills::Build::Fingerprint.new.icons_digest).to eq(described_class.sha256)
    end
  end

  describe '.store' do
    around do |example|
      saved = ENV.fetch('CHARACTER_SKILL_BUILD', nil)
      example.run
    ensure
      saved.nil? ? ENV.delete('CHARACTER_SKILL_BUILD') : ENV['CHARACTER_SKILL_BUILD'] = saved
    end

    it 'queues the stale build when the snapshot changed, in the build mode' do
      ENV['CHARACTER_SKILL_BUILD'] = 'write'
      expect { put_icon_snapshot([]) }.to have_enqueued_job(CharacterSkills::StaleBuildJob)
      expect { put_icon_snapshot([]) }.not_to have_enqueued_job(CharacterSkills::StaleBuildJob)
    end

    it 'queues nothing when the build is off' do
      ENV['CHARACTER_SKILL_BUILD'] = 'off'
      expect { put_icon_snapshot([]) }.not_to have_enqueued_job(CharacterSkills::StaleBuildJob)
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

    before { put_icon_snapshot(entries) }

    def icon(position:, ordinal:, name_en:)
      key = { granblue_id: '3030003000', style: 1, kind: 'ability', position: position, ordinal: ordinal }
      described_class.icon_for(key, name_en: name_en)
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
