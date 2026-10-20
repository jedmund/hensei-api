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

  it 'aborts before writing when a row has neither title' do
    weapons['1040908300'].update_columns(wiki_en: 'Something Else')
    expect { migration.up }.to raise_error(/Missing Weapon 1040908300/)
    expect(weapons['1040505700'].reload.wiki_en).to eq('Raphael')
  end
end
