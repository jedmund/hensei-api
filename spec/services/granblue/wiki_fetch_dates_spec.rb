# frozen_string_literal: true

require 'rails_helper'

# Every write of fetched wikitext records when it was fetched.
RSpec.describe 'Wiki fetch dates' do
  let(:now) { Time.zone.parse('2026-10-15 12:00') }

  around { |example| travel_to(now) { example.run } }

  describe Granblue::WikiFetcher do
    before do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).and_return('{{Page}}')
    end

    %i[weapon summon character].each do |factory|
      it "stamps wiki_raw_fetched_at on a #{factory}" do
        entity = create(factory, wiki_en: 'Some Page', wiki_raw: nil)

        described_class.new.fetch_and_store(entity)

        expect(entity.reload).to have_attributes(wiki_raw: '{{Page}}', wiki_raw_fetched_at: now)
      end
    end
  end

  describe Granblue::Downloaders::JpWikiDownloader do
    %i[weapon summon character].each do |factory|
      it "stamps wiki_raw_jp_fetched_at on a #{factory}" do
        entity = create(factory, wiki_raw_jp: nil)
        client = instance_double(Granblue::Parsers::JpWiki, fetch: '<html></html>')

        described_class.new(entity, client: client, jp_title: 'ページ').download

        expect(entity.reload).to have_attributes(wiki_raw_jp: '<html></html>', wiki_raw_jp_fetched_at: now)
      end
    end
  end

  describe Granblue::Parsers::CharacterParser do
    let(:character) { create(:character, wiki_en: 'Some Character', wiki_raw: nil) }

    # Only the wikitext write is under test, not the field parse.
    before { allow_any_instance_of(described_class).to receive(:parse).and_return({}) }

    it 'stamps a real fetch' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).and_return('{{Character}}')

      described_class.new(granblue_id: character.granblue_id).fetch

      expect(character.reload.wiki_raw_fetched_at).to eq(now)
    end

    it 'does not restamp a re-parse of the stored text' do
      character.update!(wiki_raw: '{{Character}}', wiki_raw_fetched_at: 1.week.ago)

      described_class.new(granblue_id: character.granblue_id, use_local: true).fetch

      expect(character.reload.wiki_raw_fetched_at).to eq(1.week.ago)
    end
  end

  describe 'saving batch-preview wikitext', type: :request do
    let(:editor) { create(:user, role: 7) }
    let(:headers) do
      token = Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, expires_in: 30.days, scopes: 'public')
      { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
    end

    it 'stamps wiki_raw_fetched_at when a summon is created with wikitext' do
      post '/api/v1/summons', headers: headers, params: {
        summon: { granblue_id: '2040999000', name_en: 'Test Summon', rarity: 3, element: 4, wiki_raw: '{{Summon}}' }
      }.to_json

      expect(response).to have_http_status(:created)
      expect(Summon.find_by(granblue_id: '2040999000').wiki_raw_fetched_at).to eq(now)
      expect(response.parsed_body['wiki_raw_fetched_at']).to be_present
    end

    it 'stamps on update only when the wikitext changes' do
      weapon = create(:weapon, wiki_raw: '{{Old}}', wiki_raw_fetched_at: 1.week.ago)

      put "/api/v1/weapons/#{weapon.id}", headers: headers, params: { weapon: { wiki_raw: '{{Old}}' } }.to_json
      expect(weapon.reload.wiki_raw_fetched_at).to eq(1.week.ago)

      put "/api/v1/weapons/#{weapon.id}", headers: headers, params: { weapon: { wiki_raw: '{{New}}' } }.to_json
      expect(response).to have_http_status(:ok)
      expect(weapon.reload.wiki_raw_fetched_at).to eq(now)
    end

    it 'stamps a character update with new wikitext' do
      character = create(:character, wiki_raw: nil)

      put "/api/v1/characters/#{character.id}", headers: headers,
                                                params: { character: { wiki_raw: '{{Character}}' } }.to_json

      expect(character.reload.wiki_raw_fetched_at).to eq(now)
    end
  end
end
