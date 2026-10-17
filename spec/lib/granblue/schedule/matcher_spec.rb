# frozen_string_literal: true

require 'rails_helper'

# Matches the synthetic October 2026 official post (it mirrors the real post's
# structure and dates) against the real wiki event_history rows for October.
RSpec.describe Granblue::Schedule::Matcher do
  subject(:matcher) { described_class.new }

  let(:fixture_dir) { Rails.root.join('spec/fixtures/schedule') }
  let(:jst) { ActiveSupport::TimeZone['Asia/Tokyo'] }
  let(:wiki) do
    Granblue::Schedule::WikiSource.new.parse(File.read(fixture_dir.join('event_history.json')),
                                             from: jst.local(2026, 10, 1), to: jst.local(2026, 10, 31, 23, 59))
  end
  let(:official) do
    source = Granblue::Schedule::OfficialPostSource.new
    news = File.read(fixture_dir.join('official_news_synthetic.json'))
    source.parse_post(source.find_monthly_post(news, year: 2026, month: 10))
  end
  let(:candidates) { matcher.match(wiki: wiki, official: official) }

  def candidate(name_en)
    candidates.find { |c| c[:name_en] == name_en }
  end

  describe '#match on the October 2026 fixtures' do
    it 'pairs each official event with its wiki record' do
      pairs = candidates.select { |c| c[:sources].size == 2 }.to_h { |c| [c[:name_en], c[:name_jp]] }

      expect(pairs).to eq(
        'Gin Tama: Shonen Jump Is Best Enjoyed Cover to Cover' => '銀魂 少年ならジャンプの裏表紙までちゃんと楽しめ',
        'My Hero Academia: Rescue Another World' => '僕のヒーローアカデミア レスキュー・アナザーワールド',
        'Helping the Genius Alchemist' => '天才錬金術師のお手伝い ～ハイド・アンド・シーツ～',
        'Dread Barrage' => 'ドレッドバラージュ'
      )
    end

    it 'agrees on times, elements and the alchemy kind' do
      expect(candidate('Helping the Genius Alchemist')).to include(kind_guess: 'alchemy', disagreements: [])
    end

    # The official post calls them 復刻コラボ; a returning collab is still a collab.
    it 'agrees on collab for the returning collabs' do
      disagreements = candidates.select { |c| c[:sources].size == 2 }.flat_map { |c| c[:disagreements] }

      expect(disagreements).to eq([])
    end

    it 'keeps wiki-only events as single-source candidates' do
      singles = candidates.select { |c| c[:sources].size == 1 }

      expect(singles.map { |c| c[:name_en] }).to contain_exactly(
        'Farewell, Cold Heart', 'Trick or Treat', 'New Story Event'
      )
      expect(singles.first).to include(disagreements: [], alternatives: [], overlap: nil)
    end

    it 'sorts candidates by start time' do
      expect(candidates.map { |c| c[:starts_at] }).to eq(candidates.map { |c| c[:starts_at] }.sort)
    end

    it 'agrees on the Dread Barrage boss element and kind' do
      barrage = candidate('Dread Barrage')

      expect(barrage).to include(element: 'Earth', kind_guess: 'dread_barrage', disagreements: [])
      expect(barrage[:starts_at]).to eq(jst.local(2026, 10, 22, 19))
    end

    it 'does not fuse Dread Barrage into the alchemy event it sits inside' do
      barrage = candidate('Dread Barrage')

      expect(barrage[:sources]['official_site'][:name_jp]).to eq('ドレッドバラージュ')
      expect(barrage[:sources]['gbf_wiki'][:source_id]).to eq('0e4accabab7a2c070e278f4e0f2bc5d7e150b040')
    end

    it 'lists Trick or Treat, which shares the alchemy start time, as an alternative' do
      expect(candidate('Helping the Genius Alchemist')[:alternatives]).to eq(
        [{ source: 'gbf_wiki', source_id: '5ecdab736175a086989268226f0d41fb0f600998', overlap: 0.517 }]
      )
    end

    it 'merges names, images and sources from both sides' do
      gintama = candidate('Gin Tama: Shonen Jump Is Best Enjoyed Cover to Cover')

      expect(gintama).to include(kind_guess: 'collab', image_en: 'banner_gintama_1.png', overlap: 1.0)
      expect(gintama[:image_jp]).to be_nil
      expect(gintama[:sources].keys).to contain_exactly('gbf_wiki', 'official_site')
    end
  end

  describe 'pairing rules' do
    def record(source, name, starts_at, ends_at, **extra)
      Granblue::Schedule::Normalization.record(
        source: source, source_id: name, starts_at: starts_at, ends_at: ends_at,
        (source == 'gbf_wiki' ? :name_en : :name_jp) => name, **extra
      )
    end

    let(:day) { jst.local(2026, 10, 7, 17) }

    it 'never pairs back-to-back windows' do
      w = record('gbf_wiki', 'A', day, day + 7.days)
      o = record('official_site', 'B', day + 7.days, day + 14.days)

      expect(matcher.match(wiki: [w], official: [o]).map { |c| c[:sources].size }).to eq([1, 1])
    end

    it 'pairs a small overlap when the start times match' do
      w = record('gbf_wiki', 'A', day, day + 1.day)
      o = record('official_site', 'B', day, day + 10.days)

      expect(matcher.match(wiki: [w], official: [o]).first[:sources].size).to eq(2)
    end

    it 'pairs a small overlap when the names are alike' do
      w = record('gbf_wiki', 'Proving Grounds', day, day + 1.day)
      o = record('official_site', 'Proving Grounds', day - 5.days, day + 5.days)

      expect(matcher.match(wiki: [w], official: [o]).first[:name_similarity]).to eq(1.0)
    end

    it 'leaves a small, unnamed overlap unpaired' do
      w = record('gbf_wiki', 'A', day, day + 1.day)
      o = record('official_site', 'B', day - 5.days, day + 5.days)

      expect(matcher.match(wiki: [w], official: [o]).size).to eq(2)
    end

    it 'records a kind disagreement' do
      w = record('gbf_wiki', 'A', day, day + 7.days, kind_guess: 'story_event')
      o = record('official_site', 'B', day, day + 7.days, kind_guess: 'collab')

      expect(matcher.match(wiki: [w], official: [o]).first[:disagreements])
        .to eq([{ field: :kind_guess, 'gbf_wiki' => 'story_event', 'official_site' => 'collab' }])
    end

    it 'records an element disagreement and takes the official element' do
      w = record('gbf_wiki', 'A', day, day + 7.days, element: 'Wind')
      o = record('official_site', 'B', day, day + 7.days, element: 'Earth')
      merged = matcher.match(wiki: [w], official: [o]).first

      expect(merged[:element]).to eq('Earth')
      expect(merged[:disagreements]).to eq([{ field: :element, 'gbf_wiki' => 'Wind', 'official_site' => 'Earth' }])
    end

    it 'handles empty inputs' do
      expect(matcher.match(wiki: [], official: [])).to eq([])
    end
  end

  describe '.name_similarity' do
    it 'ignores case, punctuation and width' do
      expect(described_class.name_similarity('Dread Barrage!', 'ｄｒｅａｄ　barrage')).to eq(1.0)
    end

    it 'is 0 for blanks and partial for related names' do
      expect(described_class.name_similarity(nil, 'x')).to eq(0.0)
      expect(described_class.name_similarity('Unite and Fight', 'Unite & Fight')).to be_between(0.5, 1.0)
    end
  end

  describe '.overlap' do
    it 'is intersection over union' do
      a = { starts_at: jst.local(2026, 10, 1), ends_at: jst.local(2026, 10, 3) }
      b = { starts_at: jst.local(2026, 10, 2), ends_at: jst.local(2026, 10, 4) }

      expect(described_class.overlap(a, b)).to be_within(0.001).of(1.0 / 3)
    end
  end
end
