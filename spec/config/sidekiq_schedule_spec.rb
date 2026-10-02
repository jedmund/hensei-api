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
end
