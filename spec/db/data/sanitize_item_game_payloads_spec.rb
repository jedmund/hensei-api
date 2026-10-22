# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SanitizeItemGamePayloads' do
  include ActiveJob::TestHelper

  let(:migration_class) do
    require Rails.root.join('db/data/20261021120000_sanitize_item_game_payloads') unless defined?(SanitizeItemGamePayloads)
    SanitizeItemGamePayloads
  end
  let(:item) { { 'id' => '1040815000', 'name' => 'Sword', 'skill1' => { 'name' => 'Might' } } }
  let(:account) { { 'user' => { 'param' => { 'viewer_id' => '1' } }, 'param' => { 'level' => '150' } } }

  # As older code stored them (the models now clean on assignment).
  def set_raw(record, column, value)
    record.class.where(id: record.id).update_all("#{column} = #{record.class.connection.quote(JSON.generate(value))}::jsonb")
  end

  def stored(record, column) = record.class.where(id: record.id).pick(column)

  def run
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  it 'cleans stored payloads in place, idempotently, logging counts only' do
    weapon = create(:weapon)
    summon = create(:summon)
    clean = create(:weapon)
    set_raw(weapon, :game_raw_en, item.merge(account))
    set_raw(summon, :game_raw_jp, item.merge(account))
    set_raw(clean, :game_raw_en, item)

    output = nil
    expect { output = run }.not_to have_enqueued_job
    expect(stored(weapon, :game_raw_en)).to eq(item)
    expect(stored(summon, :game_raw_jp)).to eq(item)
    expect(stored(clean, :game_raw_en)).to eq(item)
    expect(output).to include('weapons.game_raw_en: 2 checked, 1 cleaned', 'summons.game_raw_jp: 1 checked, 1 cleaned')
    expect(output).not_to include('viewer_id', 'Sword')

    expect(run).to include('weapons.game_raw_en: 2 checked, 0 cleaned')
  end
end
