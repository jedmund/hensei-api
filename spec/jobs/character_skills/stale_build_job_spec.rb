# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::StaleBuildJob do
  let(:wiki) do
    "{{Character\n|abilitycount=1\n|a1_name=Fire\n|a1_effdesc=Gain {{status|Shield}}.\n|a1_cd=7\n|a1_icon=Ability_m_100_1.png\n}}"
  end
  let!(:character) { Character.without_skill_build { create(:character, granblue_id: '3040900001', wiki_raw: wiki) } }

  around do |example|
    saved = ENV.fetch('CHARACTER_SKILL_BUILD', nil)
    example.run
  ensure
    saved.nil? ? ENV.delete('CHARACTER_SKILL_BUILD') : ENV['CHARACTER_SKILL_BUILD'] = saved
  end

  def names = CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id }).pluck(:name_en)

  it 'does nothing when the build is off' do
    ENV['CHARACTER_SKILL_BUILD'] = 'off'
    expect(described_class.perform_now).to be_nil
    expect(names).to be_empty
  end

  it 'builds the stale characters in write mode, with no stored status list' do
    ENV['CHARACTER_SKILL_BUILD'] = 'write'
    Granblue::Parsers::StatusList.reset!
    expect(Source.where(kind: Granblue::Parsers::StatusList::KIND)).to be_empty

    summary = described_class.perform_now
    expect(summary.failed).to eq(0)
    expect(names).to eq(['Fire'])
    # Without the list, names use the fallbacks and statuses have no game display id yet.
    expect(Status.find_by(name_en: 'Shield')).to have_attributes(game_status_id: nil)
  end
end
