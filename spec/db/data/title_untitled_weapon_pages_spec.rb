# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TitleUntitledWeaponPages' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261102220000_title_untitled_weapon_pages') unless defined?(TitleUntitledWeaponPages)
    TitleUntitledWeaponPages
  end

  def run
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  # A weapon whose page was stored untitled (an editor import before the fix).
  def untitled_weapon(wiki_en:, granblue_id:)
    weapon = create(:weapon, wiki_en: wiki_en, granblue_id: granblue_id)
    Source.create!(owner: weapon, kind: 'wiki_raw', key: '', body: '{{Pasted}}', sha256: Source.digest('{{Pasted}}'),
                   fetched_at: Time.current)
    weapon
  end

  it 'titles a lone untitled page with the page name and leaves the rest' do
    lone = untitled_weapon(wiki_en: 'Ragnarok', granblue_id: '1040030000')
    unnamed = untitled_weapon(wiki_en: nil, granblue_id: '1040030001')
    both = untitled_weapon(wiki_en: 'Blade', granblue_id: '1040030002')
    WeaponSource.create!(weapon: both, kind: 'wiki_raw', key: 'Blade', body: '{{Fetched}}', fetched_at: Time.current,
                         page_kind: 'inline')

    output = run

    expect(WeaponSource.where(weapon_id: lone.id).pluck(:key)).to eq(['Ragnarok'])
    expect(Source.owned_by(unnamed).pluck(:key)).to eq([''])
    expect(Source.owned_by(both).where(kind: 'wiki_raw').pluck(:key)).to contain_exactly('', 'Blade')
    expect(Weapon.find(lone.id).wiki_raw).to eq('{{Pasted}}')
    expect(output).to include('1 titled: 1040030000')
    expect(output).not_to include('{{')
  end

  it 'is idempotent' do
    untitled_weapon(wiki_en: 'Ragnarok', granblue_id: '1040030000')
    run
    expect(run).to include('0 titled')
  end
end
