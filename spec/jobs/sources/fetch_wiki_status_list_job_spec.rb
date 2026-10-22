# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sources::FetchWikiStatusListJob do
  around do |example|
    saved = ENV.fetch('CHARACTER_SKILL_BUILD', nil)
    example.run
  ensure
    saved.nil? ? ENV.delete('CHARACTER_SKILL_BUILD') : ENV['CHARACTER_SKILL_BUILD'] = saved
  end

  def fetch_returns(changed:)
    source = Source.new(sha256: 'abcdef1234567890')
    allow(Sources::WikiStatusList).to receive(:fetch!).and_return(Sources::WikiStatusList::Result.new(source: source, changed: changed))
  end

  it 'queues the stale build when the list changed' do
    ENV['CHARACTER_SKILL_BUILD'] = 'write'
    fetch_returns(changed: true)
    expect { described_class.perform_now }.to have_enqueued_job(CharacterSkills::StaleBuildJob)
  end

  it 'queues nothing when the list is unchanged' do
    ENV['CHARACTER_SKILL_BUILD'] = 'write'
    fetch_returns(changed: false)
    expect { described_class.perform_now }.not_to have_enqueued_job(CharacterSkills::StaleBuildJob)
  end

  it 'queues nothing when the build is off' do
    ENV['CHARACTER_SKILL_BUILD'] = 'off'
    fetch_returns(changed: true)
    expect { described_class.perform_now }.not_to have_enqueued_job(CharacterSkills::StaleBuildJob)
  end

  it "discards a page that doesn't validate (retrying won't help; the stored list stays)" do
    allow(Sources::WikiStatusList).to receive(:fetch!).and_raise(Granblue::Parsers::StatusList::Invalid, 'no buffs or debuffs')
    expect { described_class.perform_now }.not_to have_enqueued_job(described_class)
  end

  it 'retries a failed fetch later instead of raising' do
    allow(Sources::WikiStatusList).to receive(:fetch!).and_raise(RuntimeError, "gbf.wiki didn't return Module:StatusList")
    expect { described_class.perform_now }.to have_enqueued_job(described_class)
  end

  it 'gives up after three attempts and keeps the stored list' do
    Source.put(nil, Granblue::Parsers::StatusList::KIND, 'stored', key: Granblue::Parsers::StatusList::KEY, fetched_at: Time.current)
    allow(Sources::WikiStatusList).to receive(:fetch!).and_raise(RuntimeError, 'timeout')
    job = described_class.new
    job.exception_executions = { '[StandardError]' => 2 }
    job.executions = 2
    expect { job.perform_now }.not_to have_enqueued_job(described_class)
    expect(Source.fetch(nil, Granblue::Parsers::StatusList::KIND, key: Granblue::Parsers::StatusList::KEY).body).to eq('stored')
  end
end
