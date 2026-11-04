# frozen_string_literal: true

require 'rails_helper'

# The shared pipeline, through the character, weapon and summon queries. The
# request spec (spec/requests/api/v1/search_spec.rb) covers every filter.
RSpec.describe CatalogSearchQuery do
  def call(query_class, locale: 'en', **params)
    query_class.call(ActionController::Parameters.new(params).permit!, locale: locale)
  end

  describe CharacterSearchQuery do
    let!(:alpha) { create(:character, name_en: 'Zyxalpha', name_jp: 'ズィクスい', proficiency1: 2, race1: 3) }
    let!(:beta) { create(:character, name_en: 'Zyxbeta', name_jp: 'ズィクスあ', proficiency1: 4, proficiency2: 2) }

    it 'matches a proficiency in either slot' do
      expect(call(described_class, filters: { 'proficiency1' => ['2'] })).to include(alpha, beta)
      expect(call(described_class, filters: { 'proficiency1' => [4] })).to include(beta)
      expect(call(described_class, filters: { 'proficiency1' => [4] })).not_to include(alpha)
    end

    it 'drops excluded ids' do
      expect(call(described_class, query: 'Zyx', exclude: [beta.id]).to_a).to eq([alpha])
    end

    it 'searches the language name and keeps rank order' do
      expect(call(described_class, query: 'ズィクスあ', locale: 'ja').to_a).to eq([beta])
      expect(call(described_class, query: 'Zyxalpha').first).to eq(alpha)
    end

    it 'sorts by the language name' do
      mine = [alpha, beta]
      expect(call(described_class, sort: 'name').to_a & mine).to eq([alpha, beta])
      expect(call(described_class, sort: 'name', locale: 'ja').to_a & mine).to eq([beta, alpha])
    end

    it 'skips blank filters and a one-character query' do
      expect(call(described_class, query: 'Z', filters: { 'rarity' => [], 'race' => '' }).count).to eq(Character.count)
    end

    it 'ignores filters that are not a hash' do
      expect(call(described_class, filters: 'x').count).to eq(Character.count)
    end
  end

  describe WeaponSearchQuery do
    it 'maps params to weapon columns and promotions' do
      series = create(:weapon_series)
      match = create(:weapon, proficiency: 5, weapon_series: series, promotions: [3])
      other = create(:weapon, proficiency: 5, promotions: [2])

      result = call(described_class, filters: { 'proficiency1' => [5], 'series' => [series.id], 'promotions' => [3, 4] })
      expect(result.to_a).to eq([match])
      expect(call(described_class, filters: { 'promotions' => [2] })).to include(other)
    end

    it 'lists the newest first without a query or sort' do
      newest = create(:weapon, release_date: '2099-01-01')
      expect(call(described_class).first).to eq(newest)
    end
  end

  describe SummonSearchQuery do
    it 'filters by subaura only when it is true' do
      aura = create(:summon, subaura: true)
      plain = create(:summon, subaura: false)
      expect(call(described_class, filters: { 'subaura' => true })).to include(aura)
      expect(call(described_class, filters: { 'subaura' => true })).not_to include(plain)
      expect(call(described_class, filters: { 'subaura' => false })).to include(aura, plain)
    end
  end

  describe GuidebookSearchQuery do
    it 'searches names in the language, or lists every guidebook' do
      book = create(:guidebook, name_en: 'Zyxbook', name_jp: 'ズィクス本')
      expect(call(described_class, query: 'Zyxbook').to_a).to eq([book])
      expect(call(described_class, query: 'ズィクス本', locale: 'ja').to_a).to eq([book])
      expect(call(described_class).count).to eq(Guidebook.count)
    end
  end
end
