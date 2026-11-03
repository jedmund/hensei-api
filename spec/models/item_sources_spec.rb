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
    let(:weapon) { create(:weapon, wiki_en: 'Blade') }
    let(:fetched_at) { Time.zone.parse('2026-10-02 09:00') }

    def store_page(body)
      WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: body, fetched_at: fetched_at,
                           page_kind: 'inline')
    end

    def untitled_page(body)
      Source.create!(owner: weapon, kind: 'wiki_raw', key: '', body: body, sha256: Source.digest(body),
                     fetched_at: fetched_at)
    end

    it 'titles a pasted page with the page name, so the store and the build see it' do
      pasted = create(:weapon, wiki_en: 'Pasted Blade', wiki_raw: '{{Pasted}}')

      expect(Source.owned_by(pasted).pluck(:kind, :key)).to eq([['wiki_raw', 'Pasted Blade']])
      expect(WeaponSource.where(weapon_id: pasted.id).pluck(:key)).to eq(['Pasted Blade'])
      expect(Weapon.find(pasted.id).wiki_raw).to eq('{{Pasted}}')
    end

    it "keeps the '' row for a weapon with no page name" do
      unnamed = create(:weapon, wiki_en: nil, wiki_raw: '{{Pasted}}')

      expect(Source.owned_by(unnamed).pluck(:kind, :key)).to eq([['wiki_raw', '']])
      expect(WeaponSource.where(weapon_id: unnamed.id)).to be_empty
    end

    it 'retitles an untitled page on the next write, keeping one row' do
      untitled_page('{{Pasted}}')

      Weapon.find(weapon.id).update!(wiki_raw: '{{Edited}}')

      expect(Source.owned_by(weapon).where(kind: 'wiki_raw').pluck(:key, :body)).to eq([['Blade', '{{Edited}}']])
    end

    it 'reads the titled store page first, loaded or preloaded' do
      untitled_page('{{Pasted}}')
      store_page('{{Fetched}}')

      expect(Weapon.find(weapon.id)).to have_attributes(wiki_raw: '{{Fetched}}', wiki_raw_fetched_at: fetched_at)
      loaded = Weapon.preload_sources(Weapon.where(id: weapon.id).to_a, kinds: :wiki_raw).first
      expect(loaded.wiki_raw).to eq('{{Fetched}}')
      expect(Weapon.with_source(:wiki_raw)).to include(weapon)
    end

    it 'writes an edit to the titled page, keeping its key and page kind' do
      page = store_page('{{Fetched}}')

      Weapon.find(weapon.id).update!(wiki_raw: '{{Edited}}')

      expect(page.reload).to have_attributes(body: '{{Edited}}', key: 'Blade', page_kind: 'inline')
      expect(Source.owned_by(weapon).where(kind: 'wiki_raw').count).to eq(1)
    end

    it "leaves the weapon's other store pages out of a preload" do
      store_page('{{Fetched}}')
      WeaponSource.create!(weapon: weapon, kind: 'expanded', key: 'Blade', body: 'expansion', fetched_at: fetched_at)

      loaded = Weapon.preload_sources(Weapon.where(id: weapon.id).to_a).first
      expect(loaded.sources.map(&:kind)).to eq(['wiki_raw'])
    end
  end
end
