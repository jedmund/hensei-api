# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CopyCharacterSourcesToSourcesTable' do
  let(:migration_class) do
    unless defined?(CopyCharacterSourcesToSourcesTable)
      require Rails.root.join('db/data/20261020210000_copy_character_sources_to_sources_table')
    end
    CopyCharacterSourcesToSourcesTable
  end
  let(:fetched_at) { Time.utc(2026, 10, 15) }
  let(:page) { '<html><head><title>t</title></head><body><div id="menu">m</div><div id="body"><p>本文</p></div></body></html>' }
  let(:payload) { { 'id' => '1', 'b' => 2, 'ability' => { 'z' => 1, 'a' => 0 } } }

  # The columns as the old code left them (the model no longer writes them).
  def set_columns(character, **values)
    conn = Character.connection
    sets = values.map do |column, value|
      sql = value.is_a?(Hash) ? "#{conn.quote(JSON.generate(value))}::jsonb" : conn.quote(value)
      "#{column} = #{sql}"
    end
    conn.execute("UPDATE characters SET #{sets.join(', ')} WHERE id = #{conn.quote(character.id)}")
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  let!(:full) do
    create(:character).tap do |c|
      set_columns(c, wiki_raw: '{{Character}}', wiki_raw_fetched_at: fetched_at, wiki_raw_jp: page,
                     wiki_raw_jp_fetched_at: fetched_at, game_raw_en: payload)
    end
  end
  let!(:blank) do
    create(:character).tap do |c|
      set_columns(c, wiki_raw: '', wiki_raw_jp: nil)
      Character.connection.execute("UPDATE characters SET game_raw_en = 'null'::jsonb, game_raw_jp = '{}'::jsonb " \
                                   "WHERE id = #{Character.connection.quote(c.id)}")
    end
  end

  it 'copies each non-blank column into an owned source, trimmed and canonical' do
    run

    expect(Source.owned_by(full).pluck(:kind)).to contain_exactly('wiki_raw', 'wiki_raw_jp', 'game_raw_en')
    expect(Source.fetch(full, :wiki_raw)).to have_attributes(body: '{{Character}}', fetched_at: fetched_at,
                                                             sha256: Digest::SHA256.hexdigest('{{Character}}'))
    expect(Source.fetch(full, :wiki_raw_jp)).to have_attributes(body: Granblue::JpWikiPage.trim(page), fetched_at: fetched_at)
    expect(Source.fetch(full, :wiki_raw_jp).body).to eq('<div id="body"><p>本文</p></div>')
    expect(Source.fetch(full, :game_raw_en)).to have_attributes(body: '{"ability":{"a":0,"z":1},"b":2,"id":"1"}',
                                                                fetched_at: nil)
    expect(full.reload.game_raw_en).to eq(payload)
  end

  it 'makes no row for blank text, JSON null or an empty payload' do
    run
    expect(Source.owned_by(blank)).to be_empty
  end

  it 'is idempotent and keeps a row already written through the store' do
    Source.put(full, :wiki_raw, '{{Character|newer=1}}', skip_owner_hook: true)
    run
    run

    expect(Source.owned_by(full).count).to eq(3)
    expect(Source.read(full, :wiki_raw)).to eq('{{Character|newer=1}}')
  end

  it 'queues no skill builds' do
    expect { run }.not_to have_enqueued_job(CharacterSkills::BuildJob)
  end

  it 'copies in batches past the first' do
    stub_const("#{migration_class}::BATCH", 1)
    extra = create(:character).tap { |c| set_columns(c, wiki_raw: '{{Extra}}') }
    run
    expect(Source.read(extra, :wiki_raw)).to eq('{{Extra}}')
    expect(Source.where(kind: 'wiki_raw').count).to eq(2)
  end

  it 'records when it ran, for the sync task' do
    run
    expect(CharacterSkills::SourceSync.copied_at).to be_within(1.minute).of(Time.current)
    expect(Source.maximum(:updated_at)).to be <= CharacterSkills::SourceSync.copied_at
  end

  it 'is irreversible' do
    expect { migration_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end

  it 'logs counts only' do
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up

    expect(output.string).to include('wiki_raw: 1 copied, 1 blank', 'game_raw_en: 1 copied, 1 blank')
    expect(output.string).not_to include('Character}}', '本文')
  end
end
