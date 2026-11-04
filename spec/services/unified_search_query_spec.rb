# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnifiedSearchQuery do
  def call(locale: 'en', **params)
    described_class.call(ActionController::Parameters.new(params).permit!, locale: locale)
  end

  def searchables(results)
    results.map(&:searchable)
  end

  let!(:character) { create(:character, name_en: 'Zyxcharacter', name_jp: 'ズィクスキャラ') }
  let!(:summon) { create(:summon, name_en: 'Zyxsummon', name_jp: 'ズィクス召喚') }

  it 'finds English names by trigram similarity' do
    expect(searchables(call(query: 'Zyxcharacter'))).to include(character)
  end

  it 'falls back to a prefix search when the trigram search finds fewer than five' do
    expect(searchables(call(query: 'Zyx'))).to include(character, summon)
  end

  it 'prefix-searches in Japanese' do
    expect(searchables(call(query: 'ズィクス', locale: 'ja'))).to include(character, summon)
  end

  it 'drops excluded granblue ids' do
    results = searchables(call(query: 'Zyx', exclude: [summon.granblue_id]))
    expect(results).to include(character)
    expect(results).not_to include(summon)
  end

  it 'returns no more than ten' do
    create_list(:weapon, 10, name_en: 'Zyxweapon')
    expect(call(query: 'Zyxweapon').size).to eq(10)
  end

  it 'returns nothing without a query' do
    expect(call.to_a).to eq([])
  end
end
