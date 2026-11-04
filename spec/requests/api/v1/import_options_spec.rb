# frozen_string_literal: true

require 'rails_helper'

# POST /import options the extension's uploadPartyData sends (raid_id, name,
# visibility), raid detection, body checks, and the game-data series mapping on
# /import/{weapons,summons,characters}.
RSpec.describe 'Import options and game-data series', type: :request do
  let(:user) { create(:user) }
  let(:editor) { create(:user, role: 7) }
  let(:headers) { headers_for(user) }
  let(:deck) { JSON.parse(Rails.root.join('spec/fixtures/deck_sample.json').read) }

  def headers_for(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def imported_party
    Party.find(response.parsed_body['party_id'])
  end

  describe 'POST /api/v1/import' do
    it 'answers with the party and builds its grid from the deck' do
      post '/api/v1/import', params: { import: deck }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.keys).to eq(%w[shortcode party_id warnings])
      party = imported_party
      expect(response.parsed_body['shortcode']).to eq(party.shortcode)
      expect(party).to have_attributes(user_id: user.id, visibility: user.default_import_visibility, name: nil)
      # The deck's items the canonical seed catalogue has, as the processors place them.
      expect(party.weapons.map { |w| [w.weapon.granblue_id, w.position, w.uncap_level, w.transcendence_step] })
        .to eq([['1040310600', 6, 6, 5]])
      expect(party.characters.order(:position).map { |c| [c.character.granblue_id, c.uncap_level, c.perpetuity] })
        .to eq([['3040425000', 4, true], ['3040499000', 4, true], ['3040519000', 4, true],
                ['3040161000', 5, false], ['3040167000', 5, true]])
      expect(party.summons.order(:position).map { |s| [s.summon.granblue_id, s.position, s.uncap_level] })
        .to eq([['2040094000', -1, 6], ['2040158000', 0, 3], ['2040425000', 1, 4], ['2040244000', 2, 5],
                ['2040056000', 3, 6], ['2040398000', 4, 4], ['2040306000', 5, 4], ['2040056000', 6, 6]])
      expect(party.job.name_en).to eq('Manadiver')
    end

    it 'takes the name and visibility the extension sends' do
      post '/api/v1/import', params: { import: deck, name: 'Fire Farming', visibility: '3' }.to_json, headers: headers

      expect(imported_party).to have_attributes(name: 'Fire Farming', visibility: 3)
    end

    it 'ignores a visibility it does not know' do
      post '/api/v1/import', params: { import: deck, visibility: 9 }.to_json, headers: headers

      expect(imported_party.visibility).to eq(user.default_import_visibility)
    end

    it 'sets the raid the user picked, by id or slug' do
      raid = create(:raid)

      post '/api/v1/import', params: { import: deck, raid_id: raid.id }.to_json, headers: headers
      expect(imported_party).to have_attributes(raid_id: raid.id, extra: raid.group.extra)

      post '/api/v1/import', params: { import: deck, raid_id: raid.slug }.to_json, headers: headers
      expect(imported_party.raid_id).to eq(raid.id)
    end

    it 'leaves the raid empty for a raid it cannot find' do
      post '/api/v1/import', params: { import: deck, raid_id: 'no-such-raid' }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(imported_party.raid_id).to be_nil
    end

    it 'detects Farming (V2) from 13 weapons and 5 characters' do
      farming = Raid.find_by(slug: 'farming-v2') || create(:raid, slug: 'farming-v2')

      post '/api/v1/import', params: { import: deck }.to_json, headers: headers

      expect(imported_party.raid_id).to eq(farming.id)
    end

    it 'detects Farming from 10 weapons and 5 characters' do
      farming = Raid.find_by(slug: 'farming') || create(:raid, slug: 'farming')
      weapons = deck.dig('deck', 'pc', 'weapons')
      deck['deck']['pc']['weapons'] = weapons.first(10).to_h

      post '/api/v1/import', params: { import: deck }.to_json, headers: headers

      expect(imported_party.raid_id).to eq(farming.id)
    end

    it 'refuses a body that is too large' do
      post '/api/v1/import', params: { import: deck, padding: 'x' * 1.megabyte }.to_json, headers: headers

      expect(response).to have_http_status(:content_too_large)
      expect(response.parsed_body).to eq('error' => 'payload_too_large')
    end

    it 'refuses an import that is not an object' do
      post '/api/v1/import', params: { import: [deck] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Invalid JSON data')
    end

    it 'refuses a deck without characters' do
      deck['deck'].delete('npc')
      post '/api/v1/import', params: { import: deck }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Invalid deck data')
    end

    it 'refuses a kind it does not know' do
      post '/api/v1/import', params: { kind: 'tower' }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'unknown_kind',
                                         'message' => 'kind must be solomonis_party, solomonis_run or left out')
    end

    it 'does not create a party without a signed-in user' do
      expect do
        post '/api/v1/import', params: { import: deck }.to_json, headers: { 'Content-Type' => 'application/json' }
      end.not_to change(Party, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Import failed due to an unexpected error. Please try again.')
    end
  end

  describe 'POST /api/v1/import/weapons' do
    let!(:weapon) { create(:weapon, granblue_id: '1040815000', weapon_series: nil) }
    let(:series) { WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, slug: 'dark-opus') }

    it 'sets the weapon series from the payload' do
      series
      post '/api/v1/import/weapons?lang=en', params: { 'id' => '1040815000', 'series_id' => '3' }.to_json,
                                             headers: headers_for(editor)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('message' => 'Weapon gamedata updated successfully')
      expect(weapon.reload.weapon_series).to eq(series)
    end

    it 'keeps the series for an id it does not map' do
      weapon.update!(weapon_series: series)
      post '/api/v1/import/weapons?lang=en', params: { 'id' => '1040815000', 'series_id' => '99' }.to_json,
                                             headers: headers_for(editor)

      expect(weapon.reload.weapon_series).to eq(series)
    end

    it 'is a 404 for a weapon it does not have' do
      post '/api/v1/import/weapons?lang=en', params: { 'id' => '1049999999' }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq('error' => 'Weapon not found')
    end

    it 'needs a language' do
      post '/api/v1/import/weapons?lang=fr', params: { 'id' => '1040815000' }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Invalid language')
      expect(weapon.reload.game_raw_en).to be_nil
    end
  end

  describe 'POST /api/v1/import/summons' do
    let!(:summon) { create(:summon, granblue_id: '2040001000') }
    let(:series) { SummonSeries.find_by(slug: 'magna') || create(:summon_series, slug: 'magna') }

    it 'sets the summon series from master.series_id' do
      series
      post '/api/v1/import/summons?lang=jp', params: { 'master' => { 'id' => '2040001000', 'series_id' => '3' },
                                                       'id' => '2040001000' }.to_json,
                                             headers: headers_for(editor)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('message' => 'Summon gamedata updated successfully')
      expect(summon.reload.summon_series).to eq(series)
    end

    it 'is a 404 for a summon it does not have' do
      post '/api/v1/import/summons?lang=en', params: { 'id' => '2049999999' }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq('error' => 'Summon not found')
    end

    it 'needs a language' do
      post '/api/v1/import/summons', params: { 'id' => '2040001000' }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Invalid language')
    end
  end

  describe 'POST /api/v1/import/characters' do
    let!(:character) { create(:character, granblue_id: '3040377000') }
    let(:series) { CharacterSeries.find_by(slug: 'grand') || create(:character_series, slug: 'grand') }

    it 'adds the character series from the list in master.series_id, once' do
      series
      body = { 'master' => { 'id' => '3040377000', 'series_id' => ['7'] } }.to_json

      2.times { post '/api/v1/import/characters?lang=en', params: body, headers: headers_for(editor) }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('message' => 'Character gamedata updated successfully')
      expect(character.reload.character_series_records).to eq([series])
    end

    it 'is a 404 for a character it does not have' do
      post '/api/v1/import/characters?lang=en', params: { 'id' => '3049999999' }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq('error' => 'Character not found')
    end

    it 'needs a language when the payload has none to read' do
      post '/api/v1/import/characters', params: { 'id' => '3040377000' }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Invalid language')
    end
  end
end
