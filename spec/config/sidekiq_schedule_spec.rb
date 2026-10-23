# frozen_string_literal: true

require 'rails_helper'
require 'fugit'

# sidekiq-scheduler only reads jobs nested under :scheduler: -> :schedule:.
# Anything else is silently ignored, so recurring jobs never run.
RSpec.describe 'config/sidekiq.yml schedule' do
  let(:config) { YAML.load_file(Rails.root.join('config/sidekiq.yml')) }
  let(:schedule) { config.dig(:scheduler, :schedule) }

  it 'nests recurring jobs where sidekiq-scheduler reads them' do
    expect(schedule).to be_a(Hash)
    expect(schedule).to include('party_difficulty_sweep')
  end

  it 'gives every job a real class, a valid cron and a listened queue' do
    queues = config[:queues]

    schedule.each do |name, job|
      expect(job['class'].safe_constantize).to be_present, "#{name}: unknown class #{job['class']}"
      expect(Fugit.parse_cron(job['cron'])).to be_present, "#{name}: invalid cron #{job['cron']}"
      expect(queues).to include(job['queue']), "#{name}: queue #{job['queue']} isn't processed"
    end
  end

  it 'refreshes the status list on the 2nd and the 20th, late evening JST' do
    job = schedule.fetch('wiki_status_list')
    cron = Fugit.parse_cron(job['cron'])
    expect(job['class']).to eq('Sources::FetchWikiStatusListJob')
    expect(cron.timezone.name).to eq('Asia/Tokyo')
    expect(cron.monthdays).to eq([2, 20])
    expect([cron.hours, cron.minutes]).to eq([[23], [30]])
  end

  it 'exports the icon snapshot on the same days, after the status list refresh' do
    job = schedule.fetch('character_skill_icon_snapshot')
    cron = Fugit.parse_cron(job['cron'])
    status_list = Fugit.parse_cron(schedule.fetch('wiki_status_list')['cron'])
    expect(job['class']).to eq('CharacterSkills::ExportIconSnapshotJob')
    expect(job['queue']).to eq('maintenance')
    expect(cron.timezone.name).to eq('Asia/Tokyo')
    expect(cron.monthdays).to eq(status_list.monthdays)
    expect([cron.hours, cron.minutes]).to eq([[23], [45]])
    expect(cron.next_time(Time.utc(2026, 11, 1)).to_t).to be > status_list.next_time(Time.utc(2026, 11, 1)).to_t
  end
end
