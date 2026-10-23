# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::SourceSanitizer do
  include ActiveJob::TestHelper

  let(:io) { StringIO.new }
  let(:character) { Character.without_skill_build { create(:character) } }
  let(:payload) { { 'style' => 1, 'ability' => { '1' => { 'name' => 'Fire' } } } }
  let(:fetched_at) { Time.utc(2026, 10, 1) }

  it 'cleans stored payloads, keeps fetch times, queues nothing, and is idempotent' do
    # As a copy that ran before the migration sanitized (Source.put doesn't sanitize).
    Source.put(character, :game_raw_en, payload.merge('user' => { 'id' => 1 }, 'user_npc_id' => 2),
               fetched_at: fetched_at, skip_owner_hook: true)
    Source.put(Character.without_skill_build { create(:character) }, :game_raw_jp, payload, skip_owner_hook: true)

    results = nil
    expect { results = described_class.new(io: io).call }.not_to have_enqueued_job
    expect(results).to eq('game_raw_en' => [1, 1], 'game_raw_jp' => [1, 0])
    expect(Source.fetch(character, :game_raw_en)).to have_attributes(value: payload, fetched_at: fetched_at)
    expect(io.string).not_to include('user')

    expect(described_class.new(io: io).call).to eq('game_raw_en' => [1, 0], 'game_raw_jp' => [1, 0])
  end
end
