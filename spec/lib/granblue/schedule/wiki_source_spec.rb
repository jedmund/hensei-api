# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Schedule::WikiSource do
  subject(:source) { described_class.new }

  let(:fixture_dir) { Rails.root.join('spec/fixtures/schedule') }
  let(:jst) { ActiveSupport::TimeZone['Asia/Tokyo'] }

  # Real cargoquery response, June–November 2026 (26 rows).
  describe '#parse on the real event_history fixture' do
    let(:records) { source.parse(File.read(fixture_dir.join('event_history.json'))) }
    let(:october) { records.select { |r| r[:starts_at].month == 10 } }

    def find(name, month)
      records.find { |r| r[:name_en] == name && r[:starts_at].month == month }
    end

    it 'reads every row without warnings' do
      expect(records.size).to eq(26)
      expect(source.warnings).to eq([])
    end

    it 'returns the normalized hash shape' do
      expect(records.first.keys).to eq(Granblue::Schedule::Normalization::RECORD_KEYS)
      expect(records.map { |r| r[:source] }.uniq).to eq(['gbf_wiki'])
    end

    it 'reads October 2026 in JST from utc_start/utc_end' do
      expect(october.map { |r| [r[:name_en], r[:starts_at], r[:ends_at]] }).to eq(
        [
          ['Gin Tama: Shonen Jump Is Best Enjoyed Cover to Cover', jst.local(2026, 10, 7, 17), jst.local(2026, 10, 14, 16, 59)],
          ['My Hero Academia: Rescue Another World', jst.local(2026, 10, 14, 17), jst.local(2026, 10, 21, 16, 59)],
          ['Trick or Treat', jst.local(2026, 10, 17, 5), jst.local(2026, 11, 15, 4, 59)],
          ['Helping the Genius Alchemist', jst.local(2026, 10, 17, 5), jst.local(2026, 11, 1, 4, 59)],
          ['Dread Barrage', jst.local(2026, 10, 22, 19), jst.local(2026, 10, 29, 18, 59)],
          ['New Story Event', jst.local(2026, 10, 29, 19), jst.local(2026, 11, 6, 20, 59)]
        ]
      )
      expect(october.first[:starts_at].time_zone.name).to eq('Asia/Tokyo')
    end

    it 'maps grp to kinds and falls back to name patterns' do
      kinds = records.to_h { |r| [r[:name_en], r[:kind_guess]] }

      expect(kinds).to include(
        'Unite and Fight' => 'unite_and_fight',
        'Dread Barrage' => 'dread_barrage',
        'Rise of the Beasts' => 'farming',
        'Gin Tama: Shonen Jump Is Best Enjoyed Cover to Cover' => 'collab',
        'My Hero Academia: Rescue Another World' => 'collab',
        'BLEACH: Echoes in the Blue Hollow' => 'collab',
        'Skyscope Summer Missions' => 'other',
        '10.1 Billion Crystal Bonanza! Granblue Summer Festival' => 'other',
        'Trick or Treat' => 'other',
        'Farewell, Cold Heart' => nil,
        'Helping the Genius Alchemist' => 'alchemy',
        'Chisui Village' => nil
      )
    end

    it 'maps the boss element to element names' do
      expect(find('Dread Barrage', 10)[:element]).to eq('Earth')
      expect(find('Dread Barrage', 8)[:element]).to eq('Fire')
      expect(find('Unite and Fight', 11)[:element]).to eq('Light')
      expect(find('Rise of the Beasts', 7)[:element]).to be_nil
    end

    it 'uses unique_key, jpname and the first banner image' do
      gw = find('Unite and Fight', 11)

      expect(gw).to include(source_id: '991e45f12e52f11c1bb8a673cfe738a3347c7574', name_jp: '決戦！星の古戦場')
      expect(find('Gin Tama: Shonen Jump Is Best Enjoyed Cover to Cover', 10))
        .to include(image_en: 'banner_gintama_1.png', image_jp: nil, name_jp: nil)
    end

    it 'filters to a window' do
      names = source.parse(File.read(fixture_dir.join('event_history.json')),
                           from: jst.local(2026, 11, 7), to: jst.local(2026, 11, 30)).map { |r| r[:name_en] }

      expect(names).to eq(['Trick or Treat', 'Unite and Fight'])
    end
  end

  describe '#parse on synthetic edge cases' do
    let(:records) { source.parse(File.read(fixture_dir.join('event_history_synthetic.json'))) }

    it 'skips rows without a name or epochs and reports odd values' do
      expect(records.map { |r| r[:name_en] }).to eq(['Proving Grounds', 'Unite and Fight', 'Mystery Missions'])
      expect(source.warnings).to contain_exactly(
        'Proving Grounds: unmapped grp "Proving Grounds"',
        'Proving Grounds: unrecognised element "plasma"',
        'Unite and Fight: element "fire" and unf_element "water" differ',
        'Mystery Missions: time_known is "no"',
        'row 3: no name, skipped',
        'Undated Event: no readable utc_start/utc_end, skipped'
      )
    end

    it 'guesses rerun from the name and leaves an unmapped grp to the name patterns' do
      row = { 'name' => 'Rerun: Chisui Village', 'utc start' => '1782633600', 'utc end' => '1783339140' }

      expect(source.parse({ 'cargoquery' => [{ 'title' => row }] }).first[:kind_guess]).to eq('rerun')
      expect(records.first[:kind_guess]).to be_nil
    end

    it 'never reads jst_start as a time' do
      expect(records.first[:starts_at]).to eq(ActiveSupport::TimeZone['Asia/Tokyo'].local(2026, 12, 1, 19))
    end

    it 'falls back to name when enname is blank and skips blank image entries' do
      expect(records.third[:name_en]).to eq('Mystery Missions')
      expect(records.second[:image_en]).to eq('Banner A.png')
      expect(records.second[:element]).to eq('Fire')
    end
  end

  describe '#parse on errors' do
    # The first live fetch (2026-10-17, Module:Events' aliased field names) came back as this.
    it 'reads the saved MediaWiki internal error as a warning' do
      expect(source.parse(File.read(fixture_dir.join('event_history_error.json')))).to eq([])
      expect(source.warnings.first).to start_with('cargoquery error: internal_api_error_MediaWiki\\Exception\\MWException')
    end

    it 'turns a cargoquery error into a warning' do
      expect(source.parse({ 'error' => { 'code' => 'x', 'info' => 'bad field' } })).to eq([])
      expect(source.warnings).to eq(['cargoquery error: x bad field'])
    end
  end

  describe '#fetch' do
    let(:response) { instance_double(HTTParty::Response, code: 200, body: '{"cargoquery":[]}') }
    let(:from) { Time.utc(2026, 7, 1) }
    let(:to) { Time.utc(2027, 1, 1) }

    before do
      allow(Rails.application.credentials).to receive(:wiki_user_agent).and_return('TestBot/1.0')
    end

    it 'makes one cargoquery request on the real columns with the wiki user agent' do
      allow(HTTParty).to receive(:get).and_return(response)

      expect(source.fetch(from: from, to: to)).to eq('{"cargoquery":[]}')
      expect(HTTParty).to have_received(:get).once.with(
        'https://gbf.wiki/api.php',
        hash_including(
          query: hash_including(
            action: 'cargoquery', tables: 'event_history', order_by: 'utc_start', limit: 100,
            fields: 'unique_key,name,type,grp,enname,jpname,wiki_page,time_known,time_start,time_end,' \
                    'utc_start,utc_end,jst_start,jst_end,enimage,jpimage,unf_element,element',
            where: "utc_start >= #{from.to_i} AND utc_start <= #{to.to_i}"
          ),
          headers: { 'User-Agent' => 'TestBot/1.0' }
        )
      )
    end

    it 'raises without retrying on a Cloudflare challenge' do
      blocked = instance_double(HTTParty::Response, code: 403, body: '<title>Just a moment...</title>')
      allow(HTTParty).to receive(:get).and_return(blocked)

      expect { source.fetch }.to raise_error(Granblue::WikiError, /Cloudflare/)
      expect(HTTParty).to have_received(:get).once
    end

    it 'raises on a non-JSON body' do
      allow(HTTParty).to receive(:get).and_return(instance_double(HTTParty::Response, code: 200, body: '<html>'))

      expect { source.fetch }.to raise_error(Granblue::WikiError, /not JSON/)
    end

    it 'raises on other status codes' do
      allow(HTTParty).to receive(:get).and_return(instance_double(HTTParty::Response, code: 500, body: '{}'))

      expect { source.fetch }.to raise_error(Granblue::WikiError, /Unexpected response/)
    end

    it 'refuses to fetch without a user agent' do
      allow(Rails.application.credentials).to receive(:wiki_user_agent).and_return(nil)
      allow(HTTParty).to receive(:get)

      expect { source.fetch }.to raise_error(Granblue::WikiError, /wiki_user_agent/)
      expect(HTTParty).not_to have_received(:get)
    end
  end
end
