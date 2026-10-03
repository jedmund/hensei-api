require 'rails_helper'
require Rails.root.join('db/data/20261003170000_strip_event_promo_rarity_name_suffixes')

RSpec.describe StripEventPromoRarityNameSuffixes do
  subject(:migration) { described_class.new }

  let!(:event) { CharacterSeries.find_by(slug: 'event') || create(:character_series, slug: 'event') }
  let!(:promo) { CharacterSeries.find_by(slug: 'promo') || create(:character_series, slug: 'promo') }
  let!(:characters) do
    described_class::CHARACTERS.to_h do |granblue_id, name_en, name_jp|
      attributes = { name_en: name_en, name_jp: name_jp }
      # The canonical seed already carries some of these characters.
      character = Character.find_by(granblue_id: granblue_id)&.tap { |row| row.update_columns(attributes) }
      [granblue_id, character || create(:character, granblue_id: granblue_id, **attributes)]
    end
  end

  def find(name_en)
    granblue_id, = described_class::CHARACTERS.find { |_, name| name == name_en }
    characters.fetch(granblue_id).reload
  end

  it 'strips the suffixes and tags Event and Promo characters, rerunnably' do
    2.times do
      migration.up
      expect(find('Stan (Event)')).to have_attributes(name_en: 'Stan', character_series_records: [event])
      expect(find('Naoise (Promo)')).to have_attributes(name_en: 'Naoise', character_series_records: [promo])
      expect(find('Lamretta (R)')).to have_attributes(name_en: 'Lamretta', name_jp: 'ラムレッダ')
      expect(find('Pengy').name_jp).to eq('ペンギー')
    end
  end

  it 'keeps element suffixes' do
    migration.up
    expect(find('Vira (Promo)')).to have_attributes(name_en: 'Vira', name_jp: 'ヴィーラ(火属性ver)')
  end

  it 'does not tag rarity variants' do
    migration.up
    expect(find('Vira (SSR)').character_series_records).to be_empty
  end
end
