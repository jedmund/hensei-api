# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::BuildJob do
  let(:wiki) do
    "{{Character\n|abilitycount=1\n|a1_name=Fire\n|a1_effdesc=Deal damage.\n|a1_cd=7\n|a1_icon=Ability_m_100_1.png\n}}"
  end
  let(:character) { Character.without_skill_build { create(:character, granblue_id: '3040900001', wiki_raw: wiki) } }

  around do |example|
    saved = ENV.fetch('CHARACTER_SKILL_BUILD', nil)
    ENV.delete('CHARACTER_SKILL_BUILD')
    example.run
  ensure
    saved.nil? ? ENV.delete('CHARACTER_SKILL_BUILD') : ENV['CHARACTER_SKILL_BUILD'] = saved
  end

  def names = CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id }).pluck(:name_en)

  it 'builds a character with no skills even in shadow mode' do
    ENV['CHARACTER_SKILL_BUILD'] = 'shadow'
    summary = described_class.perform_now(character.id)
    expect(summary.mode).to eq('write')
    expect(names).to eq(['Fire'])
    expect(character.reload.character_skill_build_fingerprint).to be_present
  end

  it 'only reports for a character with skills in shadow mode' do
    described_class.perform_now(character.id)
    put_source(character, :wiki_raw, wiki.sub('Fire', 'Blaze'))
    ENV['CHARACTER_SKILL_BUILD'] = 'shadow'

    summary = described_class.perform_now(character.id)
    expect(summary.mode).to eq('shadow')
    expect(summary.differing).to eq(1)
    expect(names).to eq(['Fire'])
  end

  it 'writes a character with skills in write mode' do
    described_class.perform_now(character.id)
    put_source(character, :wiki_raw, wiki.sub('Fire', 'Blaze'))
    ENV['CHARACTER_SKILL_BUILD'] = 'write'

    described_class.perform_now(character.id)
    expect(names).to eq(['Blaze'])
  end

  it 'queues the icon download for new stems after a write' do
    expect { described_class.perform_now(character.id) }
      .to have_enqueued_job(CharacterSkills::IconDownloadJob).with(['100_1'])
  end

  it 'is discarded when the character is gone' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end

  context 'when another build is running' do
    include BuildLockHelpers

    it 're-queues itself while the same character is being built' do
      held_elsewhere(:character, character.id) do
        expect { described_class.perform_now(character.id) }
          .to have_enqueued_job(described_class).with(character.id)
          .at(a_value_within(1.second).of(described_class::RETRY_WAIT.from_now))
      end
      expect(names).to be_empty
    end

    it 're-queues itself during the stale build' do
      held_elsewhere(:all) do
        expect { described_class.perform_now(character.id) }.to have_enqueued_job(described_class).with(character.id)
      end
      expect(names).to be_empty
    end

    it 'builds while a different character is being built' do
      held_elsewhere(:character, 'another') { described_class.perform_now(character.id) }
      expect(names).to eq(['Fire'])
    end
  end
end
