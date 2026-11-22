# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Wonders::SeedGenerator do
  let(:fixtures) { Rails.root.join('spec/fixtures/wonders') }
  let(:wikitext) { fixtures.join('Wonders.wikitext').read }
  let(:overrides) { YAML.safe_load(Rails.root.join('db/data/wonders/overrides.yml').read) }
  let(:en_captures) { described_class::DEFAULT_EN_CAPTURES.map { |path| JSON.parse(Rails.root.join(path).read) } }
  let(:ja_captures) { described_class::DEFAULT_JA_CAPTURES.map { |path| JSON.parse(Rails.root.join(path).read) } }

  def generate(wiki: wikitext, english: en_captures, japanese: ja_captures, with: overrides)
    described_class.new(wikitext: wiki, en_captures: english, ja_captures: japanese, overrides: with).catalogue
  end

  def wonder(catalogue, granblue_id)
    catalogue['wonders'].find { |w| w['granblue_id'] == granblue_id }
  end

  it 'matches the committed seed file (rerun `bin/rails wonders:generate_seed` after changing inputs)' do
    committed = JSON.parse(Rails.root.join('db/data/wonders/catalogue.json').read)

    expect(generate).to eq(committed)
  end

  it 'seeds every wiki Wonder, joined to the captures' do
    catalogue = generate

    expect(catalogue['wonders'].size).to eq(57)
    expect(catalogue['wonders'].pluck('granblue_id')).not_to include('9002')
    expect(wonder(catalogue, '9005')['name_en']).to eq('Everlasting Premium Friday')
    expect(wonder(catalogue, '9008')).to include('kind' => 'leveled', 'element' => 2, 'sort_order' => 2,
                                                 'hidden_in_unite_and_fight' => true)
  end

  it 'sanitizes game HTML into plain text' do
    descriptions = generate['wonders'].flat_map { |w| [w['description_en'], w['description_jp']] }.compact

    expect(descriptions.grep(/<[^>]+>/)).to be_empty
    expect(wonder(generate, '1001')['description_jp']).to include("\n")
  end

  it 'fills JA text and action_ids from any capture' do
    thief = wonder(generate, '9001')

    expect(thief['name_jp']).to eq('怪盗が残した地図')
    expect(thief['effects'].first).to include('action_id' => 109_001, 'text_jp' => '強化大成功率が1％上昇する。')
  end

  it 'lets a capture supersede the overrides (Ring of The Devil)' do
    devil = wonder(generate, '2005')

    expect(devil['name_jp']).to eq('リング・オブ・デビル')
    expect(devil['description_jp']).to start_with("「理の沙」の力が結実し、具現化した指輪。\n")
    expect(devil['effects'].first).to include('action_id' => 200_501, 'text_jp' => '火属性キャラのHPが30％UPする。',
                                              'text_en' => "Gives a 30% boost to fire allies' HP.")
  end

  it 'keeps derived JA text but leaves the unknown description and action_id null' do
    %w[2001 2004].each do |granblue_id|
      ring = wonder(generate, granblue_id)

      expect(ring['name_jp']).to be_present
      expect(ring['description_jp']).to be_nil
      expect(ring['effects'].first['action_id']).to be_nil
    end
    expect(wonder(generate, '2004')['effects'].first['text_jp']).to eq('風属性キャラのHPが30％UPする。')
  end

  it 'fills Premium FRIED SHRIMP from the fourth capture' do
    shrimp = wonder(generate, '9004')

    expect(shrimp).to include('name_jp' => 'プレミアムエビフライ', 'description_jp' => 'ゆとりある豊かな生活をもたらす黄金の像。')
    expect(shrimp['effects'].first).to include('action_id' => 109_004, 'text_jp' => '金曜日から日曜日までEXPが1％上昇する。')
  end

  it 'records which summon a Ring does not stack with' do
    expect(wonder(generate, '2003')['effects'].pluck('details')).to all(include('no_stack_with_summon' => 'Death'))
    expect(wonder(generate, '2005')['effects'].first['details']).to eq('no_stack_with_summon' => 'The Devil')
  end

  it 'lets capture text replace derived override text' do
    ja = ja_captures.deep_dup
    ring = ja.first.first.deep_dup.merge('category_id' => '8', 'item' => [
                                           { 'item_id' => '2001', 'name' => '本物の名前', 'comment' => '',
                                             'category_id' => '8',
                                             'action_list' => [{ 'action_no' => 1, 'action_id' => 200_101,
                                                                 'comment' => '本物の効果' }] }
                                         ])
    ja.first << ring

    justice = wonder(generate(japanese: ja), '2001')
    expect(justice['name_jp']).to eq('本物の名前')
    expect(justice['effects'].first).to include('text_jp' => '本物の効果', 'action_id' => 200_101)
  end

  it 'fails when a wiki Wonder has no id' do
    without_id = overrides.deep_dup.tap { |o| o['ids'].delete("Thief's Map") }
    en_without_thief = en_captures
    ja_without_thief = ja_captures.map do |response|
      response.map { |category| category.merge('item' => category['item'].reject { |i| i['item_id'] == '9001' }) }
    end

    expect { generate(english: en_without_thief, japanese: ja_without_thief, with: without_id) }
      .to raise_error(described_class::Error, /Thief's Map/)
  end

  it 'fails when a captured Wonder is not on the wiki' do
    en = en_captures.deep_dup
    en.first.first['item'] << { 'item_id' => '9999', 'name' => 'Not On The Wiki', 'category_id' => '1' }

    expect { generate(english: en) }.to raise_error(described_class::Error, /9999/)
  end

  it 'rejects unknown override fields' do
    typo = overrides.deep_dup.tap { |o| o['wonders']['9004']['nmae_jp'] = 'x' }

    expect { generate(with: typo) }.to raise_error(described_class::Error, /nmae_jp/)
  end
end
