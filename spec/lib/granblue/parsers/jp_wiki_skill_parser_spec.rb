# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::JpWikiSkillParser do
  def parse(slug)
    html = File.read(Rails.root.join("spec/fixtures/character_skills/character-#{slug}-jpwiki.html"))
    described_class.new(build(:character, wiki_raw_jp: html)).parse
  end

  it 'parses Vikala ougi, abilities (including the transform), and support' do
    result = parse(:vikala)

    aggregate_failures do
      expect(result[:ougi].map { |o| o[:name_jp] }).to include('金牙神然')
      expect(result[:abilities].map { |a| a[:name_jp] })
        .to include('グリーティング・ドーマウス', 'エンチャンテッド・ドリーム', 'エキセントリックパレード')
      expect(result[:abilities].first)
        .to include(name_jp: 'グリーティング・ドーマウス', unlock_level: nil, enhance_levels: [55], cooldown: 11)
      expect(result[:support].map { |s| s[:name_jp] }).to eq(%w[鼠神宮の主 ビート・ザ・マウス])
    end
  end

  it 'parses Caim with four abilities (plus transform) and four support skills' do
    result = parse(:caim)

    aggregate_failures do
      expect(result[:abilities].size).to eq(5)
      expect(result[:abilities].map { |a| a[:name_jp] }).to include('ブランクフェイス', 'シークレットハンズ')
      expect(result[:support].size).to eq(4)
    end
  end

  it 'parses Threo form ougi variants and abilities' do
    result = parse(:threo)

    aggregate_failures do
      expect(result[:ougi].size).to eq(6)
      expect(result[:abilities].map { |a| a[:name_jp] }).to include('グラウンドゼロ')
      expect(result[:support].size).to eq(3)
    end
  end

  it 'parses Wamdus and skips merged option sub-skills' do
    result = parse(:wamdus)

    aggregate_failures do
      expect(result[:abilities].map { |a| a[:name_jp] }).to start_with('スターヴィングドレイン', 'イノセントトキシン')
      expect(result[:abilities].size).to eq(3)
      expect(result[:support].map { |s| s[:name_jp] }).to eq(%w[ろーどーのよろこび 理外の『碧』])
    end
  end
end
