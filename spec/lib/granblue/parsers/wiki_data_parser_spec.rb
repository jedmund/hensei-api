# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::WikiDataParser do
  describe '.parse_wiki_text' do
    it 'extracts key-value pairs from wiki markup' do
      text = "|name = Katalina\n|element = Water\n|rarity = SSR"
      result = described_class.parse_wiki_text(text)

      aggregate_failures do
        expect(result['name']).to eq('Katalina')
        expect(result['element']).to eq('Water')
        expect(result['rarity']).to eq('SSR')
      end
    end

    it 'stops at Gameplay Notes section' do
      text = "|name = Katalina\n== Gameplay Notes ==\n|hidden = secret"
      result = described_class.parse_wiki_text(text)
      expect(result).to have_key('name')
      expect(result).not_to have_key('hidden')
    end

    it 'skips non-pipe lines' do
      text = "Some text\n|name = Katalina\nMore text"
      result = described_class.parse_wiki_text(text)
      expect(result.keys).to eq(['name'])
    end

    it 'skips blank values' do
      text = "|name = Katalina\n|element ="
      result = described_class.parse_wiki_text(text)
      expect(result).not_to have_key('element')
    end

    it 'handles values with equals signs' do
      text = "|link = http://example.com?a=1&b=2"
      result = described_class.parse_wiki_text(text)
      expect(result['link']).to eq('http://example.com?a=1&b=2')
    end
  end

  describe '.parse_date' do
    it 'parses valid date strings' do
      expect(described_class.parse_date('2024-03-15')).to eq(Date.new(2024, 3, 15))
    end

    it 'returns nil for invalid dates' do
      expect(described_class.parse_date('not-a-date')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.parse_date(nil)).to be_nil
    end
  end

  describe '.parse_gamewith_url' do
    it 'extracts ID from full URL' do
      url = 'https://xn--bck3aza1a2if6kra4ee0hf.gamewith.jp/article/show/519325'
      expect(described_class.parse_gamewith_url(url)).to eq('519325')
    end

    it 'returns direct numeric ID' do
      expect(described_class.parse_gamewith_url('519325')).to eq('519325')
    end

    it 'extracts from template syntax' do
      expect(described_class.parse_gamewith_url('{{{link_gamewith|519325}}}')).to eq('519325')
    end

    it 'returns nil for blank input' do
      expect(described_class.parse_gamewith_url('')).to be_nil
    end

    it 'returns nil for non-matching input' do
      expect(described_class.parse_gamewith_url('random text')).to be_nil
    end
  end

  describe '.parse_kamigame_url' do
    context 'with character URLs' do
      it 'extracts slug from full URL' do
        url = 'https://kamigame.jp/%E3%82%B0%E3%83%A9%E3%83%96%E3%83%AB/%E3%82%AD%E3%83%A3%E3%83%A9%E3%82%AF%E3%82%BF%E3%83%BC/SSR%E6%B0%B4%E7%9D%80%E3%83%AA%E3%83%83%E3%83%81.html'
        result = described_class.parse_kamigame_url(url, :character)
        expect(result).to eq('SSR水着リッチ')
      end
    end

    context 'with weapon URLs' do
      it 'extracts slug from full URL' do
        url = 'https://kamigame.jp/%E3%82%B0%E3%83%A9%E3%83%96%E3%83%AB/%E6%AD%A6%E5%99%A8/SSR/%E3%83%96%E3%83%A9%E3%82%A4%E3%83%B3%E3%83%89.html'
        result = described_class.parse_kamigame_url(url, :weapon)
        expect(result).to eq('ブラインド')
      end
    end

    context 'with summon URLs' do
      it 'extracts slug from full URL' do
        url = 'https://kamigame.jp/%E3%82%B0%E3%83%A9%E3%83%96%E3%83%AB/%E5%8F%AC%E5%96%9A%E7%9F%B3/SSR/%E3%82%A2%E3%82%B0%E3%83%8B%E3%82%B9.html'
        result = described_class.parse_kamigame_url(url, :summon)
        expect(result).to eq('SSR/アグニス')
      end
    end

    it 'handles template syntax' do
      expect(described_class.parse_kamigame_url('{{{link_kamigame|TestSlug}}}', :character)).to eq('TestSlug')
    end

    it 'returns nil for nested templates' do
      expect(described_class.parse_kamigame_url('{{{link_kamigame|{{{jpname|}}}}}}', :character)).to be_nil
    end

    it 'returns nil for blank input' do
      expect(described_class.parse_kamigame_url('', :character)).to be_nil
    end

    it 'strips .html from direct slugs' do
      expect(described_class.parse_kamigame_url('TestSlug.html', :character)).to eq('TestSlug')
    end
  end

  describe '.character_season_from_series' do
    it 'returns season for seasonal series' do
      aggregate_failures do
        expect(described_class.character_season_from_series('valentine', '')).to eq(1)
        expect(described_class.character_season_from_series('summer', '')).to eq(3)
        expect(described_class.character_season_from_series('halloween', '')).to eq(4)
        expect(described_class.character_season_from_series('holiday', '')).to eq(5)
        expect(described_class.character_season_from_series('formal', '')).to eq(2)
      end
    end

    it 'falls back to obtain field' do
      expect(described_class.character_season_from_series('', 'premium,summer')).to eq(3)
    end

    it 'returns nil for non-seasonal' do
      expect(described_class.character_season_from_series('grand', 'premium')).to be_nil
    end
  end

  describe '.gacha_available_from_obtain' do
    it 'returns true for gacha indicators' do
      expect(described_class.gacha_available_from_obtain('premium', '')).to be true
      expect(described_class.gacha_available_from_obtain('flash', '')).to be true
    end

    it 'returns false for non-gacha indicators' do
      expect(described_class.gacha_available_from_obtain('event', '')).to be false
      expect(described_class.gacha_available_from_obtain('story', '')).to be false
    end

    it 'returns false for blank obtain' do
      expect(described_class.gacha_available_from_obtain('', '')).to be false
    end
  end

  describe '.character_promotions_from_obtain' do
    it 'returns seasonal promotion for seasonal series' do
      result = described_class.character_promotions_from_obtain('premium', 'summer')
      expect(result).to eq([7]) # Summer seasonal promotion
    end

    it 'returns standard promotions for non-seasonal' do
      result = described_class.character_promotions_from_obtain('premium', 'grand')
      expect(result).to eq([1, 4, 5]) # Premium, Flash, Legend
    end

    it 'adds classic pool when explicitly mentioned' do
      result = described_class.character_promotions_from_obtain('premium,classic', '')
      expect(result).to include(2)
    end

    it 'returns empty for non-gacha' do
      expect(described_class.character_promotions_from_obtain('event', '')).to eq([])
    end
  end

  describe '.calculate_weapon_max_level' do
    it 'returns 50 for R weapons' do
      expect(described_class.calculate_weapon_max_level(1, false, false, false)).to eq(50)
    end

    it 'returns 75 for SR weapons' do
      expect(described_class.calculate_weapon_max_level(2, false, false, false)).to eq(75)
    end

    it 'returns 100 for base SSR weapons' do
      expect(described_class.calculate_weapon_max_level(3, false, false, false)).to eq(100)
    end

    it 'returns 150 for FLB SSR weapons' do
      expect(described_class.calculate_weapon_max_level(3, true, false, false)).to eq(150)
    end

    it 'returns 200 for ULB SSR weapons' do
      expect(described_class.calculate_weapon_max_level(3, true, true, false)).to eq(200)
    end

    it 'returns 250 for transcendence SSR weapons' do
      expect(described_class.calculate_weapon_max_level(3, true, true, true)).to eq(250)
    end
  end

  describe '.calculate_summon_max_level' do
    it 'returns 30 for R summons' do
      expect(described_class.calculate_summon_max_level(1, false, false, false)).to eq(30)
    end

    it 'returns 60 for SR summons' do
      expect(described_class.calculate_summon_max_level(2, false, false, false)).to eq(60)
    end

    it 'returns 100 for base SSR summons' do
      expect(described_class.calculate_summon_max_level(3, false, false, false)).to eq(100)
    end

    it 'returns 250 for transcendence SSR summons' do
      expect(described_class.calculate_summon_max_level(3, true, true, true)).to eq(250)
    end
  end

  describe '.find_weapon_series_by_name' do
    it 'converts name to slug and queries WeaponSeries' do
      series = double('WeaponSeries', id: 42)
      allow(WeaponSeries).to receive(:find_by).with(slug: 'revenant').and_return(series)

      result = described_class.find_weapon_series_by_name('Revenant Weapons')
      expect(result).to eq(series)
    end

    it 'strips trailing Weapons/Series from name' do
      allow(WeaponSeries).to receive(:find_by).with(slug: 'revenant').and_return(nil)
      described_class.find_weapon_series_by_name('Revenant Weapons')
      expect(WeaponSeries).to have_received(:find_by).with(slug: 'revenant')
    end

    it 'returns nil for blank name' do
      expect(described_class.find_weapon_series_by_name('')).to be_nil
    end
  end

  describe '.parse_character' do
    it 'returns empty hash for blank input' do
      expect(described_class.parse_character('')).to eq({})
    end

    it 'parses character wiki text' do
      wiki_text = <<~WIKI
        |name = Katalina
        |jpname = カタリナ
        |id = 3040001000
        |element = Water
        |rarity = SSR
        |max_evo = 5
      WIKI

      result = described_class.parse_character(wiki_text)

      aggregate_failures do
        expect(result[:name_en]).to eq('Katalina')
        expect(result[:name_jp]).to eq('カタリナ')
        expect(result[:granblue_id]).to eq('3040001000')
        expect(result[:element]).to eq(Granblue::Parsers::Wiki.elements['Water'])
        expect(result[:rarity]).to eq(Granblue::Parsers::Wiki.rarities['SSR'])
        expect(result[:flb]).to be true
        expect(result[:transcendence]).to be false
      end
    end
  end

  describe '.parse_weapon' do
    it 'returns empty hash for blank input' do
      expect(described_class.parse_weapon('')).to eq({})
    end

    it 'strips _note suffix from granblue_id' do
      wiki_text = "|id = 1040007100_note\n|name = Sword"
      result = described_class.parse_weapon(wiki_text)
      expect(result[:granblue_id]).to eq('1040007100')
    end

    it 'parses weapon uncap status' do
      wiki_text = "|name = Sword\n|evo_max = 6"
      result = described_class.parse_weapon(wiki_text)

      aggregate_failures do
        expect(result[:flb]).to be true
        expect(result[:ulb]).to be true
        expect(result[:transcendence]).to be true
        expect(result[:max_level]).to eq(250)
      end
    end
  end

  describe '.parse_summon' do
    it 'returns empty hash for blank input' do
      expect(described_class.parse_summon('')).to eq({})
    end

    it 'parses summon wiki text' do
      wiki_text = <<~WIKI
        |name = Bahamut
        |jpname = バハムート
        |id = 2040003000
        |element = Dark
        |rarity = SSR
        |max_evo = 5
      WIKI

      result = described_class.parse_summon(wiki_text)

      aggregate_failures do
        expect(result[:name_en]).to eq('Bahamut')
        expect(result[:name_jp]).to eq('バハムート')
        expect(result[:granblue_id]).to eq('2040003000')
        expect(result[:flb]).to be true
        expect(result[:ulb]).to be true
      end
    end
  end
end
