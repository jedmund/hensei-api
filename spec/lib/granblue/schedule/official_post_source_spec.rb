# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Schedule::OfficialPostSource do
  subject(:source) { described_class.new }

  let(:fixture_dir) { Rails.root.join('spec/fixtures/schedule') }
  let(:news) { File.read(fixture_dir.join('official_news_synthetic.json')) }
  let(:jst) { ActiveSupport::TimeZone['Asia/Tokyo'] }

  describe '#monthly_posts / #find_monthly_post' do
    it 'finds the monthly post in the news list by subject' do
      posts = source.monthly_posts(news)

      expect(posts.map { |p| [p[:year], p[:month], p[:post]['topics_id']] }).to eq([[2026, 10, 90_002]])
    end

    it 'finds a post by year and month' do
      post = source.find_monthly_post(news, year: 2026, month: 10)

      expect(post['subject']).to eq('これからの『グランブルーファンタジー』2026年10月号')
    end

    it 'returns nil for a month with no post' do
      expect(source.find_monthly_post(news, year: 2026, month: 11)).to be_nil
    end

    it 'matches full-width digits in the subject' do
      list = { 'list' => [{ 'subject' => 'これからの『グランブルーファンタジー』２０２６年１１月号', 'topics_id' => 1 }] }

      expect(source.find_monthly_post(list, year: 2026, month: 11)).to include('topics_id' => 1)
    end
  end

  # The synthetic news fixture mirrors the real 2026年10月号 post's structure and dates.
  describe '#parse_post on the October 2026 post' do
    let(:post) { source.find_monthly_post(news, year: 2026, month: 10) }
    let(:records) { source.parse_post(post) }
    let(:by_name) { records.index_by { |r| r[:name_jp] } }

    it 'returns one record per section with a 開催期間 block' do
      expect(records.map { |r| r[:name_jp] }).to eq(
        [
          '銀魂 少年ならジャンプの裏表紙までちゃんと楽しめ',
          '僕のヒーローアカデミア レスキュー・アナザーワールド',
          '天才錬金術師のお手伝い ～ハイド・アンド・シーツ～',
          'ドレッドバラージュ'
        ]
      )
    end

    it 'reads full ranges with the year' do
      gintama = by_name['銀魂 少年ならジャンプの裏表紙までちゃんと楽しめ']

      expect(gintama[:starts_at]).to eq(jst.local(2026, 10, 7, 17, 0))
      expect(gintama[:ends_at]).to eq(jst.local(2026, 10, 14, 16, 59))
      expect(gintama[:starts_at].time_zone.name).to eq('Asia/Tokyo')
    end

    it 'keeps the name intact when it contains the range separator' do
      expect(by_name).to have_key('天才錬金術師のお手伝い ～ハイド・アンド・シーツ～')
    end

    it 'infers the year and crosses months for yearless ranges' do
      alchemy = by_name['天才錬金術師のお手伝い ～ハイド・アンド・シーツ～']

      expect(alchemy[:starts_at]).to eq(jst.local(2026, 10, 17, 5, 0))
      expect(alchemy[:ends_at]).to eq(jst.local(2026, 11, 1, 4, 59))
    end

    it 'guesses kinds from the heading' do
      expect(records.map { |r| r[:kind_guess] }).to eq(%w[collab collab alchemy dread_barrage])
    end

    it 'stores the Dread Barrage boss element, keeping the advantaged one in raw' do
      barrage = by_name['ドレッドバラージュ']

      expect(barrage[:element]).to eq('Earth')
      expect(barrage[:raw]).to include(enemy_element: 'Earth', advantage_element: 'Wind')
    end

    it 'derives the advantaged element when the post only names the boss' do
      html = '<h1>「ドレッドバラージュ」開催</h1><h4>開催期間</h4><p>10/22（木）19:00 ～ 10/29（木）18:59</p>' \
             '<h4>敵の属性について</h4><p>ボスとして水属性の敵が登場します。</p>'

      record = source.parse(html, year: 2026, month: 10).first

      expect(record[:element]).to eq('Water')
      expect(record[:raw]).to include(enemy_element: 'Water', advantage_element: 'Earth')
    end

    it 'warns when the named boss and advantage elements do not fit' do
      html = '<h1>「ドレッドバラージュ」開催</h1><h4>開催期間</h4><p>10/22（木）19:00 ～ 10/29（木）18:59</p>' \
             '<h4>敵の属性について</h4><p>ボスは土属性です。火属性の編成を強化してください。</p>'

      record = source.parse(html, year: 2026, month: 10).first

      expect(record[:element]).to eq('Earth')
      expect(source.warnings).to eq(["ドレッドバラージュ: boss element Earth doesn't match advantage element Fire"])
    end

    it 'takes the first section image and the post id' do
      gintama = records.first

      expect(gintama[:image_jp]).to be_nil
      expect(gintama[:image_en]).to be_nil
      expect(gintama).to include(source: 'official_site', source_id: '90002:0', name_en: nil)
      expect(gintama[:raw][:period]).to eq('2026/10/7（水）17:00 ～ 2026/10/14（水）16:59')
    end

    it 'warns about announced events with no 開催期間' do
      records

      expect(source.warnings).to contain_exactly(
        '「グラブルオータムキャンペーン」開催予定: announces an event but has no 開催期間',
        '「トリック・オア・トリート！」キャンペーン開催: announces an event but has no 開催期間'
      )
    end
  end

  describe '#parse on a synthetic December issue' do
    let(:html) { File.read(fixture_dir.join('official_post_december_synthetic.html')) }
    let(:records) { source.parse(html, year: 2026, month: 12, post_id: 42) }
    let(:by_name) { records.index_by { |r| r[:name_jp] } }

    it 'reads full-width digits and the 〜 separator' do
      story = by_name['星降る夜の物語']

      expect(story[:starts_at]).to eq(jst.local(2026, 12, 5, 19, 0))
      expect(story[:ends_at]).to eq(jst.local(2026, 12, 13, 18, 59))
      expect(story[:kind_guess]).to eq('story_event')
      expect(story[:image_jp]).to eq('https://example.invalid/story.png')
    end

    it 'rolls a yearless January end into the next year' do
      gw = by_name['星の古戦場']

      expect(gw[:starts_at]).to eq(jst.local(2026, 12, 26, 19, 0))
      expect(gw[:ends_at]).to eq(jst.local(2027, 1, 3, 23, 59))
      expect(gw[:kind_guess]).to eq('unite_and_fight')
      expect(gw[:element]).to eq('Wind')
      expect(gw[:raw]).to include(enemy_element: 'Wind', advantage_element: 'Fire')
    end

    it 'keeps the first of several 開催期間 lines and warns about the rest' do
      newyear = by_name['はじまりの空']

      expect(newyear[:starts_at]).to eq(jst.local(2027, 1, 1, 5, 0))
      expect(newyear[:ends_at]).to eq(jst.local(2027, 1, 8, 4, 59))
      expect(source.warnings).to include('はじまりの空: extra 開催期間 line ignored "後半：1/8（金）5:00 ～ 1/15（金）4:59"')
    end

    it 'warns instead of guessing on lines it cannot read' do
      records

      expect(by_name).not_to have_key('謎のキャンペーン')
      expect(source.warnings).to include(
        '謎のキャンペーン: can\'t read 開催期間 line "12/20（金）メンテナンス終了後 ～ 12/31（火）23:59"',
        '「年末年始キャンペーン」開催: announces an event but has no 開催期間',
        'グッズ情報: can\'t read 開催期間 line "2027年1月28日～31日"'
      )
      expect(source.warnings.size).to eq(4)
    end

    it 'warns about an empty 開催期間 block' do
      expect(source.parse('<h1>「X」開催</h1><h4>開催期間</h4><h4>概要</h4>', year: 2026, month: 12)).to eq([])
      expect(source.warnings).to eq(['X: 開催期間 block is empty'])
    end

    it 'warns when the post has no top-level <h1> sections' do
      html = '<div><h1>「X」開催</h1><h4>開催期間</h4><p>12/5 19:00 ～ 12/13 18:59</p></div>'

      expect(source.parse(html, year: 2026, month: 12)).to eq([])
      expect(source.warnings).to eq(['no <h1> sections found; the post structure may have changed'])
    end

    it 'numbers source ids by section' do
      expect(records.map { |r| r[:source_id] }).to eq(%w[42:0 42:1 42:2])
    end
  end

  describe '#parse_period' do
    def period(line, year: 2026, month: 10)
      source.parse_period(line, year: year, month: month)
    end

    it 'reads YYYY/M/D (曜) H:MM ～ YYYY/M/D (曜) H:MM' do
      expect(period('2026/10/7（水）17:00 ～ 2026/10/14（水）16:59'))
        .to eq([jst.local(2026, 10, 7, 17), jst.local(2026, 10, 14, 16, 59)])
    end

    it 'reads M/D (曜) H:MM ～ M/D (曜) H:MM with single-digit hours' do
      expect(period('10/17（土）5:00 ～ 11/1（日）4:59'))
        .to eq([jst.local(2026, 10, 17, 5), jst.local(2026, 11, 1, 4, 59)])
    end

    it 'reads the 年月日 form with the year on one side only' do
      expect(period('2026年9月26日（土）12:00 ～ 10月12日（月）23:59'))
        .to eq([jst.local(2026, 9, 26, 12), jst.local(2026, 10, 12, 23, 59)])
    end

    it 'accepts half-width parentheses, no spaces and a trailing まで' do
      expect(period('9/26(土)12:00~10/12(月)23:59までとなっております'))
        .to eq([jst.local(2026, 9, 26, 12), jst.local(2026, 10, 12, 23, 59)])
    end

    it 'accepts dash separators' do
      expect(period('10/7（水）17:00 － 10/14（水）16:59'))
        .to eq([jst.local(2026, 10, 7, 17), jst.local(2026, 10, 14, 16, 59)])
    end

    it 'rolls hours past 23 into the next day' do
      expect(period('10/7 17:00 ～ 10/14 29:00')&.last).to eq(jst.local(2026, 10, 15, 5))
    end

    it 'puts a December issue\'s January start in the next year' do
      expect(period('1/2（土）5:00 ～ 1/9（土）4:59', month: 12))
        .to eq([jst.local(2027, 1, 2, 5), jst.local(2027, 1, 9, 4, 59)])
    end

    it 'puts a January issue\'s December start in the previous year' do
      expect(period('12/28（月）19:00 ～ 1/4（月）18:59', year: 2027, month: 1))
        .to eq([jst.local(2026, 12, 28, 19), jst.local(2027, 1, 4, 18, 59)])
    end

    it 'rejects open-ended, timeless and impossible ranges' do
      expect(period('2026年10月24日（土）12:00～')).to be_nil
      expect(period('2027年1月28日～31日')).to be_nil
      expect(period('10/7（水） ～ 10/14（水）')).to be_nil
      expect(period('2/30 17:00 ～ 3/2 16:59')).to be_nil
      expect(period('10/14 17:00 ～ 10/7 16:59')).to be_nil
      expect(period('10/7 17:00 ～ 10/8 17:00 ～ 10/9 17:00')).to be_nil
      expect(period('詳しくは後日お知らせします')).to be_nil
    end
  end
end
