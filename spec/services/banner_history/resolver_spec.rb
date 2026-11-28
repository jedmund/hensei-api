# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BannerHistory::Resolver do
  subject(:resolver) { described_class.new }

  it 'finds an item by its wiki page before its name' do
    create(:summon, granblue_id: '2049990001', name_en: 'Spec Cat', wiki_en: 'Spec Cat (Summer)')
    create(:summon, granblue_id: '2049990002', name_en: 'Spec Cat', wiki_en: 'Spec Cat')

    expect(resolver.resolve(Summon, 'Spec Cat', context: 'x').granblue_id).to eq('2049990002')
    expect(resolver.resolve(Summon, 'Spec Cat (Summer)', context: 'x').granblue_id).to eq('2049990001')
  end

  it 'falls back to an English name only one item has' do
    create(:summon, granblue_id: '2049990003', name_en: 'Spec Dragon', wiki_en: 'Spec Dragon (Summon)')
    expect(resolver.resolve(Summon, 'Spec Dragon', context: 'x').granblue_id).to eq('2049990003')
  end

  it 'treats straight and curly apostrophes as the same' do
    create(:weapon, granblue_id: '1049990001', name_en: "Spec's Dagger", wiki_en: 'Spec’s Dagger')
    expect(resolver.resolve(Weapon, "Spec's Dagger", context: 'x').granblue_id).to eq('1049990001')
  end

  it 'follows pages the wiki renamed' do
    create(:character, granblue_id: '3049990001', name_en: 'Arulumaya', wiki_en: 'Arulumaya (Holiday)')
    expect(resolver.resolve(Character, 'Arulumaya (Christmas)', context: 'x').granblue_id).to eq('3049990001')
  end

  it 'remembers a name it cannot place, and skips placeholders' do
    create(:character, name_en: 'Spec Knight', wiki_en: 'Spec Knight (Grand)')
    create(:character, name_en: 'Spec Knight', wiki_en: 'Spec Knight (Earth)')

    expect(resolver.resolve(Character, 'Spec Knight', context: '2017-12-29 flash')).to be_nil
    expect(resolver.resolve(Summon, 'Fire Summons', context: 'x')).to be_nil
    expect(resolver.unresolved.keys).to eq([['Character', 'Spec Knight']])
  end

  it 'picks the model a list holds' do
    expect(described_class.model_for('rateup_ssr_sum', 'premium')).to eq(Summon)
    expect(described_class.model_for('sparkable', 'summon')).to eq(Summon)
    expect(described_class.model_for('zodiacs', 'premium')).to eq(Character)
    expect(described_class.model_for('rateup_char', 'archive')).to eq(Character)
    expect(described_class.model_for('legacy_char', 'legend')).to eq(Weapon)
    expect(described_class.model_for('sparkable', 'character_generic')).to eq(Weapon)
  end
end
