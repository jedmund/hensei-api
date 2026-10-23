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

      it 'stores each source as an owned row; the table has no source columns' do
        expect(Source.owned_by(record).pluck(:kind)).to contain_exactly('wiki_raw', 'wiki_raw_jp', 'game_raw_en')
        expect(model.column_names).not_to include('wiki_raw', 'wiki_raw_jp', 'game_raw_en', 'game_raw_jp',
                                                  'wiki_raw_fetched_at', 'wiki_raw_jp_fetched_at')
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

  describe "a weapon's page (one row)" do
    let(:weapon) { create(:weapon, wiki_en: 'Blade', wiki_raw: '{{Pasted}}') }
    let(:fetched_at) { Time.zone.parse('2026-10-02 09:00') }

    def store_page(body)
      WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: body, fetched_at: fetched_at,
                           page_kind: 'inline')
    end

    it "is the '' row until the store has fetched the page" do
      expect(Source.owned_by(weapon).pluck(:kind, :key)).to eq([['wiki_raw', '']])
      expect(WeaponSource.count).to eq(0)
      expect(Weapon.find(weapon.id).wiki_raw).to eq('{{Pasted}}')
    end

    it 'reads the titled store page first, loaded or preloaded' do
      store_page('{{Fetched}}')

      expect(Weapon.find(weapon.id)).to have_attributes(wiki_raw: '{{Fetched}}', wiki_raw_fetched_at: fetched_at)
      loaded = Weapon.preload_sources(Weapon.where(id: weapon.id).to_a, kinds: :wiki_raw).first
      expect(loaded.wiki_raw).to eq('{{Fetched}}')
      expect(Weapon.with_source(:wiki_raw)).to include(weapon)
    end

    it 'writes an edit to the titled page, keeping its key and page kind' do
      page = store_page('{{Fetched}}')
      Source.where(owner_type: 'Weapon', owner_id: weapon.id, key: '').delete_all

      Weapon.find(weapon.id).update!(wiki_raw: '{{Edited}}')

      expect(page.reload).to have_attributes(body: '{{Edited}}', key: 'Blade', page_kind: 'inline')
      expect(Source.owned_by(weapon).where(kind: 'wiki_raw').count).to eq(1)
    end

    it "leaves the weapon's other store pages out of a preload" do
      WeaponSource.create!(weapon: weapon, kind: 'expanded', key: 'Blade', body: 'expansion', fetched_at: fetched_at)

      loaded = Weapon.preload_sources(Weapon.where(id: weapon.id).to_a).first
      expect(loaded.sources.map(&:kind)).to eq(['wiki_raw'])
    end
  end
end
