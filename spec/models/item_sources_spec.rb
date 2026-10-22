# frozen_string_literal: true

require 'rails_helper'

# D35, PR 7b: a weapon's and a summon's fetched sources live in `sources`, not their columns.
RSpec.describe 'Weapon and Summon sources' do
  let(:payload) { { 'name' => 'Blade', 'master' => { 'id' => '1040000000' }, 'user_id' => 42 } }
  let(:fetched_at) { Time.zone.parse('2026-10-01 09:00') }

  %i[weapon summon].each do |factory|
    context "with a #{factory}" do
      let(:model) { factory.to_s.classify.constantize }
      let!(:record) do
        create(factory, wiki_raw: '{{Item}}', wiki_raw_fetched_at: fetched_at, wiki_raw_jp: '<div id="body">x</div>',
                        game_raw_en: payload)
      end

      it 'stores each source as an owned row, not in the columns' do
        expect(Source.owned_by(record).pluck(:kind)).to contain_exactly('wiki_raw', 'wiki_raw_jp', 'game_raw_en')
        columns = model.where(id: record.id).pick(Arel.sql('wiki_raw'), Arel.sql('wiki_raw_jp'), Arel.sql('game_raw_en'))
        expect(columns).to eq([nil, nil, nil])
      end

      it 'reads them back through the attribute names, the payload sanitized' do
        loaded = model.find(record.id)

        expect(loaded).to have_attributes(wiki_raw: '{{Item}}', wiki_raw_fetched_at: fetched_at,
                                          wiki_raw_jp: '<div id="body">x</div>', game_raw_jp: nil)
        expect(loaded.game_raw_en).to eq(payload.except('user_id'))
      end

      it 'never loads the old columns' do
        expect(model.find(record.id).attributes.keys).not_to include('wiki_raw', 'wiki_raw_jp', 'game_raw_en', 'game_raw_jp')
      end

      it 'dates a game payload when given a fetch time' do
        record.update!(game_raw_jp: payload, game_raw_jp_fetched_at: fetched_at)
        expect(model.find(record.id).game_raw_jp_fetched_at).to eq(fetched_at)
      end

      it 'preloads its own sources in one query' do
        records = model.where(id: record.id).to_a
        model.preload_sources(records, kinds: %i[wiki_raw game_raw_en])

        queries = []
        callback = ->(*, data) { queries << data[:sql] if data[:sql].include?('"sources"') }
        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          expect(records.first.wiki_raw).to eq('{{Item}}')
          expect(records.first.game_raw_en).to eq(payload.except('user_id'))
        end
        expect(queries).to be_empty
      end
    end
  end

  it "doesn't take a weapon's store pages for its own wiki_raw" do
    weapon = create(:weapon, wiki_raw: '{{Own}}')
    WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Some Page', body: '{{Store page}}',
                         fetched_at: Time.current, page_kind: 'inline')

    loaded = Weapon.preload_sources(Weapon.where(id: weapon.id).to_a, kinds: :wiki_raw).first
    expect(loaded.wiki_raw).to eq('{{Own}}')
    expect(loaded.sources.map(&:key)).to eq([''])
    expect(Weapon.find(weapon.id).wiki_raw).to eq('{{Own}}')
  end
end
