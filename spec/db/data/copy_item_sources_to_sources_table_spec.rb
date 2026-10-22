# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CopyItemSourcesToSourcesTable' do
  let(:migration_class) do
    unless defined?(CopyItemSourcesToSourcesTable)
      require Rails.root.join('db/data/20261022110000_copy_item_sources_to_sources_table')
    end
    CopyItemSourcesToSourcesTable
  end
  let(:fetched_at) { Time.utc(2026, 10, 15) }
  let(:page) { '<html><head><title>t</title></head><body><div id="menu">m</div><div id="body"><p>本文</p></div></body></html>' }
  let(:payload) { { 'name' => 'Blade', 'master' => { 'z' => 1, 'a' => 0 }, 'user_id' => 42 } }

  # The columns as the old code left them (the models no longer write them).
  def set_columns(record, **values)
    conn = record.class.connection
    sets = values.map do |column, value|
      sql = value.is_a?(Hash) ? "#{conn.quote(JSON.generate(value))}::jsonb" : conn.quote(value)
      "#{column} = #{sql}"
    end
    conn.execute("UPDATE #{record.class.table_name} SET #{sets.join(', ')} WHERE id = #{conn.quote(record.id)}")
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  let!(:weapon) do
    create(:weapon).tap do |w|
      set_columns(w, wiki_raw: '{{Weapon}}', wiki_raw_fetched_at: fetched_at, wiki_raw_jp: page,
                     wiki_raw_jp_fetched_at: fetched_at, game_raw_jp: payload)
    end
  end
  let!(:summon) { create(:summon).tap { |s| set_columns(s, wiki_raw: '{{Summon}}', game_raw_en: payload) } }
  let!(:blank) do
    create(:weapon).tap do |w|
      set_columns(w, wiki_raw: '', wiki_raw_jp: nil)
      Weapon.connection.execute("UPDATE weapons SET game_raw_en = 'null'::jsonb, game_raw_jp = '{}'::jsonb " \
                                "WHERE id = #{Weapon.connection.quote(w.id)}")
    end
  end

  it 'copies each non-blank column into an owned source, trimmed, sanitized and canonical' do
    run

    expect(Source.owned_by(weapon).pluck(:kind)).to contain_exactly('wiki_raw', 'wiki_raw_jp', 'game_raw_jp')
    expect(Source.fetch(weapon, :wiki_raw)).to have_attributes(body: '{{Weapon}}', fetched_at: fetched_at,
                                                               sha256: Digest::SHA256.hexdigest('{{Weapon}}'))
    expect(Source.fetch(weapon, :wiki_raw_jp)).to have_attributes(body: '<div id="body"><p>本文</p></div>',
                                                                  fetched_at: fetched_at)
    expect(Source.fetch(weapon, :game_raw_jp)).to have_attributes(body: '{"master":{"a":0,"z":1},"name":"Blade"}',
                                                                  fetched_at: nil)
    expect(weapon.reload.game_raw_jp).to eq(payload.except('user_id'))
    expect(weapon.wiki_raw).to eq('{{Weapon}}')
    expect(weapon.wiki_raw_fetched_at).to eq(fetched_at)

    expect(Source.owned_by(summon).pluck(:kind)).to contain_exactly('wiki_raw', 'game_raw_en')
    expect(summon.reload.wiki_raw).to eq('{{Summon}}')
    expect(summon.game_raw_en).to eq(payload.except('user_id'))
  end

  it 'makes no row for blank text, JSON null or an empty payload' do
    run
    expect(Source.owned_by(blank)).to be_empty
  end

  it 'is idempotent and keeps a row already written through the store' do
    Source.put(weapon, :wiki_raw, '{{Weapon|newer=1}}')
    run
    run

    expect(Source.owned_by(weapon).count).to eq(3)
    expect(Source.read(weapon, :wiki_raw)).to eq('{{Weapon|newer=1}}')
  end

  it 'copies in batches past the first' do
    stub_const("#{migration_class}::BATCH", 1)
    extra = create(:weapon).tap { |w| set_columns(w, wiki_raw: '{{Extra}}') }
    run
    expect(Source.read(extra, :wiki_raw)).to eq('{{Extra}}')
    expect(Source.where(owner_type: 'Weapon', kind: 'wiki_raw').count).to eq(2)
  end

  it 'records when it first ran' do
    run
    first = ActiveRecord::Base.connection.select_value(
      "SELECT value FROM ar_internal_metadata WHERE key = 'item_sources_copied_at'"
    )
    expect(Time.iso8601(first)).to be_within(1.minute).of(Time.current)

    travel_to(1.hour.from_now) { run }
    expect(ActiveRecord::Base.connection.select_value(
             "SELECT value FROM ar_internal_metadata WHERE key = 'item_sources_copied_at'"
           )).to eq(first)
  end

  it 'is irreversible' do
    expect { migration_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end

  it 'logs counts only' do
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up

    expect(output.string).to include('weapons.wiki_raw: 1 copied, 1 blank', 'summons.game_raw_en: 1 copied, 0 blank')
    expect(output.string).not_to include('Weapon}}', '本文', 'Blade')
  end
end
