# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::ExportIconSnapshotJob do
  around do |example|
    saved = ENV.fetch('CHARACTER_SKILL_BUILD', nil)
    example.run
  ensure
    saved.nil? ? ENV.delete('CHARACTER_SKILL_BUILD') : ENV['CHARACTER_SKILL_BUILD'] = saved
  end

  let(:slot) { create(:character_skill, character: create(:character, granblue_id: '3040377000'), kind: 'ability', position: 1) }
  let!(:version) { create(:character_skill_version, character_skill: slot, ordinal: 1, name_en: 'First', game_icon: '1_1') }

  def stored_text = Source.read(nil, :icon_snapshot, key: CharacterSkills::IconSnapshot::KEY)

  it 'stores the snapshot and queues the stale build once when it changed' do
    ENV['CHARACTER_SKILL_BUILD'] = 'write'
    expect { expect(described_class.perform_now).to eq(1) }
      .to have_enqueued_job(CharacterSkills::StaleBuildJob).exactly(:once)
    expect(JSON.parse(stored_text).map { |entry| entry['game_icon'] }).to eq(['1_1'])
  end

  it 'stores nothing new and queues nothing when the snapshot is unchanged' do
    ENV['CHARACTER_SKILL_BUILD'] = 'write'
    described_class.perform_now
    expect { described_class.perform_now }.not_to have_enqueued_job(CharacterSkills::StaleBuildJob)
  end

  it 'queues the build again after an icon changed' do
    ENV['CHARACTER_SKILL_BUILD'] = 'write'
    described_class.perform_now
    version.update!(game_icon: '2_1')
    expect { described_class.perform_now }.to have_enqueued_job(CharacterSkills::StaleBuildJob).exactly(:once)
  end

  it 'still exports, but queues nothing, when the build is off' do
    ENV['CHARACTER_SKILL_BUILD'] = 'off'
    expect { described_class.perform_now }.not_to have_enqueued_job(CharacterSkills::StaleBuildJob)
    expect(stored_text).to be_present
  end

  describe '.schedule' do
    it 'queues one export DEBOUNCE from now and nothing more while it is pending' do
      expect { expect(described_class.schedule).to be_present }
        .to have_enqueued_job(described_class).at(a_value_within(1.second).of(described_class::DEBOUNCE.from_now))
      expect { expect(described_class.schedule).to be_nil }.not_to have_enqueued_job(described_class)
    end

    it 'queues the next export once the pending one started' do
      described_class.schedule
      described_class.perform_now
      expect { described_class.schedule }.to have_enqueued_job(described_class).exactly(:once)
    end

    it 'queues a new export when the pending one looks lost' do
      described_class.schedule
      travel(described_class::STALE_AFTER + 1.minute) do
        expect { described_class.schedule }.to have_enqueued_job(described_class).exactly(:once)
      end
    end
  end

  context 'when the export fails' do
    before { put_icon_snapshot([{ granblue_id: '1', style: 1, kind: 'ability', position: 1, ordinal: 1, name_en: 'Old', game_icon: '9_9' }]) }

    let!(:stored) { stored_text }

    it 'discards conflicting versions (retrying will not help) and keeps the stored snapshot' do
      create(:character_skill_version, character_skill: slot, ordinal: 1, name_en: 'Other', game_icon: '3_1')
      expect { described_class.perform_now }.not_to have_enqueued_job(described_class)
      expect(stored_text).to eq(stored)
    end

    it 'discards an export that would drop too many entries and keeps the stored snapshot' do
      many = (1..30).map { |n| { granblue_id: '2', style: 1, kind: 'ability', position: 1, ordinal: n, name_en: 'Old', game_icon: '9_9' } }
      put_icon_snapshot(many)
      stored = stored_text
      expect { described_class.perform_now }.not_to have_enqueued_job
      expect(stored_text).to eq(stored)
    end

    it 'retries a failed export later instead of raising' do
      allow(CharacterSkills::IconSnapshot).to receive(:export).and_raise(ActiveRecord::StatementInvalid, 'timeout')
      expect { described_class.perform_now }.to have_enqueued_job(described_class)
      expect(stored_text).to eq(stored)
    end

    it 'gives up after three attempts and keeps the stored snapshot' do
      allow(CharacterSkills::IconSnapshot).to receive(:export).and_raise(RuntimeError, 'timeout')
      job = described_class.new
      job.exception_executions = { '[StandardError]' => 2 }
      job.executions = 2
      expect { job.perform_now }.not_to have_enqueued_job(described_class)
      expect(stored_text).to eq(stored)
    end
  end
end
