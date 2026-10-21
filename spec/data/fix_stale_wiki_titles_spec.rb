require 'rails_helper'
require Rails.root.join('db/data/20261020170000_fix_stale_wiki_titles')

RSpec.describe FixStaleWikiTitles do
  subject(:migration) { described_class.new }

  # The canonical seed may already carry some of these rows.
  def row(model, granblue_id, wiki_en)
    record = model.find_by(granblue_id: granblue_id)&.tap { |r| r.update_columns(wiki_en: wiki_en) }
    record || create(model.name.underscore.to_sym, granblue_id: granblue_id, wiki_en: wiki_en)
  end

  let!(:weapons) do
    described_class::WEAPONS.to_h { |granblue_id, (from, _)| [granblue_id, row(Weapon, granblue_id, from)] }
  end
  let!(:characters) do
    described_class::CHARACTERS.to_h { |granblue_id, (from, _)| [granblue_id, row(Character, granblue_id, from)] }
  end

  it 'retitles every row without touching names, rerunnably' do
    raphael = weapons['1040505700']
    names = [raphael.name_en, raphael.name_jp]
    2.times do
      migration.up
      expect(raphael.reload.wiki_en).to eq('Raphael (Weapon)')
      expect([raphael.name_en, raphael.name_jp]).to eq(names)
      expect(weapons['1040402100'].reload.wiki_en).to eq('Five-Soul Staff Incendo')
      expect(characters['3040501000'].reload.wiki_en).to eq('Uriel')
      expect(characters['3030143000'].reload.wiki_en).to eq('Augusta (Promo)')
    end
  end

  it 'leaves another character sharing an id untouched' do
    style = create(:character, granblue_id: '3040515000', wiki_en: 'Sandalphon (Style)')
    migration.up
    expect(style.reload.wiki_en).to eq('Sandalphon (Style)')
  end

  it "makes the new page's stored copy the weapon's wiki_raw source" do
    weapon = weapons['1030902400']
    old_page = WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Honebami Toushirou (NPC)',
                                    body: '{{Non-party Character}}', fetched_at: 2.days.ago, page_kind: 'inline')
    stored = WeaponSource.create!(weapon: weapon, kind: 'transclusion', key: 'Honebami Toushirou (Weapon)',
                                  body: "{{Weapon\n|id=1030902400\n}}", fetched_at: 1.day.ago)

    migration.up

    sources = WeaponSource.where(weapon: weapon)
    expect(sources.pluck(:kind, :key, :page_kind)).to eq([['wiki_raw', 'Honebami Toushirou (Weapon)', 'inline']])
    expect(sources.first.body).to eq(stored.body)
    expect(sources.first.fetched_at).to be_within(1.second).of(stored.fetched_at)
    expect(WeaponSource.exists?(old_page.id)).to be(false)
    expect(weapon.reload.wiki_raw).to eq(stored.body)
  end

  it 'promotes per weapon and retitles every row sharing an id and the old title' do
    first = weapons['1040505700']
    second = create(:weapon, granblue_id: '1040505700', wiki_en: 'Raphael')
    [first, second].each_with_index do |weapon, index|
      WeaponSource.create!(weapon: weapon, kind: 'transclusion', key: 'Raphael (Weapon)',
                           body: "{{Weapon\n|id=1040505700\n|copy=#{index}\n}}", fetched_at: index.days.ago)
    end

    migration.up

    [first, second].each_with_index do |weapon, index|
      expect(weapon.reload.wiki_en).to eq('Raphael (Weapon)')
      expect(WeaponSource.where(weapon: weapon).pluck(:kind, :key)).to eq([['wiki_raw', 'Raphael (Weapon)']])
      expect(weapon.wiki_raw).to include("|copy=#{index}")
    end
  end

  it 'lets the build find the promoted page by its new title' do
    body = "{{Weapon\n|id=1030902400\n}}"
    WeaponSource.create!(weapon: weapons['1030902400'], kind: 'transclusion', key: 'Honebami Toushirou (Weapon)',
                         body: body, fetched_at: 1.day.ago)

    migration.up

    expect(WeaponSkills::SourceStore::Database.new.fetch('wiki_raw', 'Honebami Toushirou (Weapon)').body).to eq(body)
  end

  it 'keeps the sources of a retitled weapon with no stored copy of its new page' do
    weapon = weapons['1040908200']
    old_page = WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Mikazuki Munechika',
                                    body: '{{Character}}', fetched_at: 2.days.ago, page_kind: 'inline')
    weapon.update_columns(wiki_raw: old_page.body)

    migration.up

    expect(weapon.reload.wiki_en).to eq('Mikazuki Munechika (Weapon)')
    expect(WeaponSource.where(weapon: weapon).pluck(:id, :kind, :key, :body))
      .to eq([[old_page.id, 'wiki_raw', 'Mikazuki Munechika', '{{Character}}']])
    expect(weapon.wiki_raw).to eq('{{Character}}')
  end

  it 'skips a row with neither title and retitles the rest' do
    weapons['1040908300'].update_columns(wiki_en: 'Something Else')
    # say prints only while migrations are verbose, so check the call rather than stdout.
    allow(migration).to receive(:say)
    expect { migration.up }.not_to raise_error
    expect(migration).to have_received(:say)
      .with(/Skipped Weapon 1040908300: no row titled "Tsurumaru Kuninaga \(NPC\)"/)
    expect(weapons['1040908300'].reload.wiki_en).to eq('Something Else')
    expect(weapons['1040505700'].reload.wiki_en).to eq('Raphael (Weapon)')
    expect(characters['3040501000'].reload.wiki_en).to eq('Uriel')
  end
end
