# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MergeWeaponPageSources' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261023100100_merge_weapon_page_sources') unless defined?(MergeWeaponPageSources)
    MergeWeaponPageSources
  end

  def run
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  # A weapon with its own page (key '') and, when stored, the store's titled copy.
  def weapon_with(own, stored = nil)
    weapon = create(:weapon, wiki_en: "Blade #{SecureRandom.hex(2)}")
    Source.put(weapon, :wiki_raw, own)
    if stored
      WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: weapon.wiki_en, body: stored, fetched_at: Time.current,
                           page_kind: 'inline')
    end
    weapon
  end

  it "removes the '' row beside a titled one, keeps a lone '' row, and leaves store rows alone" do
    same = weapon_with('{{Page}}', '{{Page}}')
    differs = weapon_with('{{Edited}}', '{{Fetched}}')
    lone = weapon_with('{{Pasted}}')
    store = WeaponSource.pluck(:id, :sha256).sort

    output = run

    expect(Source.where(owner_type: 'Weapon', kind: 'wiki_raw').pluck(:owner_id, :key))
      .to contain_exactly([same.id, same.wiki_en], [differs.id, differs.wiki_en], [lone.id, ''])
    expect(WeaponSource.pluck(:id, :sha256).sort).to eq(store)
    expect(Weapon.find(differs.id).wiki_raw).to eq('{{Fetched}}')
    expect(Weapon.find(lone.id).wiki_raw).to eq('{{Pasted}}')
    expect(output).to include('2 duplicate rows removed (1 same as the titled page, 1 different), 1 weapons with only')
    expect(output).not_to include('{{')
  end

  it 'is idempotent' do
    weapon_with('{{Page}}', '{{Page}}')
    run
    expect(run).to include('0 duplicate rows removed')
  end
end
