# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::SourceSync do
  include ActiveJob::TestHelper

  let(:copied_at) { 1.hour.ago }
  let(:fetched_at) { Time.utc(2026, 10, 20, 12) }
  let(:page) { '<html><head></head><body><div id="menu">m</div><div id="body"><p>本文</p></div></body></html>' }
  let(:io) { StringIO.new }

  # What the old code wrote to the columns (the model no longer writes them).
  def set_columns(character, **values)
    conn = Character.connection
    sets = values.map do |column, value|
      sql = value.is_a?(Hash) ? "#{conn.quote(JSON.generate(value))}::jsonb" : conn.quote(value)
      "#{column} = #{sql}"
    end
    conn.execute("UPDATE characters SET #{sets.join(', ')} WHERE id = #{conn.quote(character.id)}")
  end

  # A row as the copy migration left it.
  def copied_row(character, kind, value)
    travel_to(copied_at - 1.minute) { Source.put(character, kind, value, fetched_at: nil, skip_owner_hook: true) }
  end

  def run = described_class.new(io: io).call

  # As the copy migration records it.
  def record_copied_at(time)
    ActiveRecord::Base.connection.execute(
      "INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) " \
      "VALUES ('#{described_class::COPIED_AT_KEY}', '#{time.utc.iso8601(6)}', now(), now()) " \
      'ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value'
    )
  end

  before { record_copied_at(copied_at) }

  let!(:character) { Character.without_skill_build { create(:character) } }

  it 'stores a column the copy missed, trimmed and dated' do
    set_columns(character, wiki_raw_jp: page, wiki_raw_jp_fetched_at: fetched_at,
                           game_raw_en: { 'style' => 1, 'ability' => { '1' => { 'name' => 'Fire' } }, 'user' => { 'id' => 1 } })

    counts = run

    expect(counts['wiki_raw_jp'].missing).to eq(1)
    expect(Source.fetch(character, :wiki_raw_jp)).to have_attributes(body: '<div id="body"><p>本文</p></div>',
                                                                     fetched_at: fetched_at)
    expect(Source.fetch(character, :game_raw_en).body).to eq('{"ability":{"1":{"name":"Fire"}},"style":1}')
  end

  it 'replaces a copied row the old code changed afterwards' do
    copied_row(character, :wiki_raw, '{{Old}}')
    set_columns(character, wiki_raw: '{{Changed after the copy}}', wiki_raw_fetched_at: fetched_at)

    expect(run['wiki_raw'].changed).to eq(1)
    expect(Source.fetch(character, :wiki_raw)).to have_attributes(body: '{{Changed after the copy}}', fetched_at: fetched_at)
  end

  it 'keeps a row written through the store after the copy' do
    copied_row(character, :wiki_raw, '{{Old}}')
    Source.put(character, :wiki_raw, '{{Refreshed after the deploy}}', skip_owner_hook: true)
    set_columns(character, wiki_raw: '{{Changed after the copy}}')

    expect(run['wiki_raw'].newer).to eq(1)
    expect(Source.read(character, :wiki_raw)).to eq('{{Refreshed after the deploy}}')
  end

  it 'counts equal and blank values and changes nothing' do
    copied_row(character, :wiki_raw, '{{Same}}')
    set_columns(character, wiki_raw: '{{Same}}', wiki_raw_jp: '')

    counts = nil
    expect { counts = run }.not_to(change { Source.maximum(:updated_at) })
    expect(counts['wiki_raw']).to have_attributes(checked: 1, same: 1, synced: 0)
    expect(counts['wiki_raw_jp']).to have_attributes(checked: 1, blank: 1, synced: 0)
  end

  it 'queues one build per character it stored, and none on a second run' do
    other = Character.without_skill_build { create(:character) }
    untouched = Character.without_skill_build { create(:character) }
    set_columns(character, wiki_raw: '{{Missed}}', game_raw_en: { 'style' => 1 })
    set_columns(other, wiki_raw: '{{Other}}')
    copied_row(untouched, :wiki_raw, '{{Same}}')
    set_columns(untouched, wiki_raw: '{{Same}}')

    expect { run }.to have_enqueued_job(CharacterSkills::BuildJob).exactly(2).times
    expect(enqueued_jobs.map { |job| job['arguments'].first }).to contain_exactly(character.id, other.id)

    clear_enqueued_jobs
    expect { expect(run['wiki_raw']).to have_attributes(same: 3, synced: 0) }.not_to have_enqueued_job
  end

  it 'keeps a copied row a refetch confirmed after the copy' do
    copied_row(character, :wiki_raw, '{{Old}}')
    Source.put(character, :wiki_raw, '{{Old}}', fetched_at: Time.current, skip_owner_hook: true)
    set_columns(character, wiki_raw: '{{Changed after the copy}}')

    expect(run['wiki_raw'].newer).to eq(1)
    expect(Source.read(character, :wiki_raw)).to eq('{{Old}}')
  end

  it 'without a recorded copy time, only fills missing rows' do
    ActiveRecord::Base.connection.execute("DELETE FROM ar_internal_metadata WHERE key = '#{described_class::COPIED_AT_KEY}'")
    copied_row(character, :wiki_raw, '{{Old}}')
    set_columns(character, wiki_raw: '{{Changed}}')

    expect(run['wiki_raw'].newer).to eq(1)
    expect(Source.read(character, :wiki_raw)).to eq('{{Old}}')
  end

  it 'skips a character deleted while it runs' do
    set_columns(character, wiki_raw: '{{Missed}}')
    allow(Character).to receive(:select).and_wrap_original do |original, *args|
      original.call(*args).tap { |relation| allow(relation).to receive(:find_by).and_return(nil) }
    end

    counts = nil
    expect { counts = run }.not_to have_enqueued_job(CharacterSkills::BuildJob)
    expect(counts['wiki_raw']).to have_attributes(deleted: 1, synced: 0)
  end

  it 'prints counts only' do
    set_columns(character, wiki_raw: '{{Secret text}}')
    run

    expect(io.string).to include('wiki_raw: 1 checked, 0 same, 1 missing')
    expect(io.string).not_to include('Secret')
  end
end
