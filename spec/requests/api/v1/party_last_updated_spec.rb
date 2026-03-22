# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party last_updated tracking', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user, edit_key: 'secret', last_updated: 3.days.ago) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:incoming_weapon) { Weapon.find_by!(granblue_id: '1040912100') }
  let(:character) { Character.find_by!(granblue_id: '3040036000') }
  let(:summon) { Summon.find_by!(granblue_id: '2040433000') }

  def last_updated_for(party)
    party.reload.last_updated
  end

  # ─────────────────────────────────────────────
  # Actions that SHOULD bump last_updated
  # ─────────────────────────────────────────────

  describe 'actions that bump last_updated' do
    describe 'PartiesController' do
      it 'sets last_updated on create' do
        params = { party: { name: 'New', visibility: 1, clear_time: 0 } }

        post '/api/v1/parties', params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        created = Party.find_by(name: 'New')
        expect(created.last_updated).to be_within(2.seconds).of(Time.current)
      end

      it 'bumps last_updated on update' do
        original = last_updated_for(party)

        params = { party: { name: 'Renamed' } }
        put "/api/v1/parties/#{party.id}", params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on remix' do
        other_party = create(:party, user: create(:user), visibility: 1)

        post "/api/v1/parties/#{other_party.shortcode}/remix", headers: headers
        expect(response).to have_http_status(:created)

        remixed = Party.find_by(source_party_id: other_party.id)
        expect(remixed.last_updated).to be_within(2.seconds).of(Time.current)
      end

      it 'bumps last_updated on grid_update (move)' do
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 0)
        original = last_updated_for(party)

        params = { operations: [{ type: 'move', entity: 'weapon', id: gw.id, position: 1 }] }
        post "/api/v1/parties/#{party.id}/grid_update", params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end
    end

    describe 'JobsController' do
      let(:job) { Job.first }

      it 'bumps last_updated on update_job' do
        original = last_updated_for(party)

        params = { party: { job_id: job.id } }
        put "/api/v1/parties/#{party.shortcode}/jobs", params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on destroy_job_skill' do
        party.update!(job: job)
        main_skill = JobSkill.find_by(job: job, main: true)
        sub_skill = JobSkill.where(job: job, sub: true).first
        party.update!(skill0: main_skill, skill1: sub_skill)
        original = last_updated_for(party)

        params = { party: { skill_position: 1 } }
        delete "/api/v1/parties/#{party.shortcode}/job_skills", params: params.to_json, headers: headers

        expect(last_updated_for(party)).to be > original
      end
    end

    describe 'GridWeaponsController' do
      it 'bumps last_updated on create' do
        original = last_updated_for(party)

        params = {
          weapon: {
            party_id: party.id, weapon_id: weapon.id, position: 0,
            mainhand: true, uncap_level: 3, transcendence_step: 0, element: weapon.element
          }
        }
        post '/api/v1/grid_weapons', params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on update_position' do
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 0)
        original = last_updated_for(party)

        put "/api/v1/parties/#{party.id}/grid_weapons/#{gw.id}/position",
            params: { position: 4 }.to_json,
            headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on swap' do
        gw1 = create(:grid_weapon, party: party, weapon: weapon, position: 0)
        gw2 = create(:grid_weapon, party: party, weapon: incoming_weapon, position: 1)
        original = last_updated_for(party)

        post "/api/v1/parties/#{party.id}/grid_weapons/swap",
             params: { source_id: gw1.id, target_id: gw2.id }.to_json,
             headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on resolve' do
        incoming_weapon.update!(flb: true, ulb: false, transcendence: false)
        conflicting = create(:grid_weapon, party: party, weapon: weapon, position: 5)
        original = last_updated_for(party)

        params = { resolve: { position: 5, incoming: incoming_weapon.id, conflicting: [conflicting.id] } }
        post '/api/v1/grid_weapons/resolve', params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on destroy' do
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 4)
        original = last_updated_for(party)

        delete "/api/v1/grid_weapons/#{gw.id}", headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on duplicate' do
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 0)
        weapon.update!(limit: false)
        original = last_updated_for(party)

        post "/api/v1/grid_weapons/#{gw.id}/duplicate",
             params: { position: 1 }.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(last_updated_for(party)).to be > original
      end
    end

    describe 'GridCharactersController' do
      it 'bumps last_updated on create' do
        original = last_updated_for(party)

        params = {
          character: {
            party_id: party.id, character_id: character.id, position: 1,
            uncap_level: 3, transcendence_step: 0, perpetuity: false,
            rings: [{ modifier: '1', strength: '1500' }],
            awakening: { id: 'character-balanced', level: 1 }
          }
        }
        post '/api/v1/grid_characters', params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on update_position' do
        gc = create(:grid_character, party: party, character: character, position: 0)
        original = last_updated_for(party)

        put "/api/v1/parties/#{party.id}/grid_characters/#{gc.id}/position",
            params: { position: 2 }.to_json,
            headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on swap' do
        gc1 = create(:grid_character, party: party, character: character, position: 0)
        other_char = Character.find_by!(granblue_id: '3040087000')
        gc2 = create(:grid_character, party: party, character: other_char, position: 1)
        original = last_updated_for(party)

        post "/api/v1/parties/#{party.id}/grid_characters/swap",
             params: { source_id: gc1.id, target_id: gc2.id }.to_json,
             headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on destroy' do
        gc = create(:grid_character, party: party, character: character, position: 0)
        original = last_updated_for(party)

        delete "/api/v1/grid_characters/#{gc.id}", headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on switch_style' do
        base_char = Character.find_by!(granblue_id: '3040087000')
        style_swap = base_char.style_swaps.first
        skip 'No style swap variant available for test character' unless style_swap

        gc = create(:grid_character, party: party, character: base_char, position: 0)
        original = last_updated_for(party)

        post "/api/v1/grid_characters/#{gc.id}/switch_style",
             params: { character: { party_id: party.id } }.to_json,
             headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end
    end

    describe 'GridSummonsController' do
      it 'bumps last_updated on create' do
        original = last_updated_for(party)

        params = {
          summon: {
            party_id: party.id, summon_id: summon.id, position: 0,
            main: true, friend: false, quick_summon: false,
            uncap_level: 3, transcendence_step: 0
          }
        }
        post '/api/v1/grid_summons', params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on update_quick_summon' do
        gs = create(:grid_summon, party: party, summon: summon, position: 2, quick_summon: false)
        original = last_updated_for(party)

        params = { summon: { id: gs.id, party_id: party.id, summon_id: summon.id, quick_summon: true } }
        post '/api/v1/grid_summons/update_quick_summon', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on update_position' do
        gs = create(:grid_summon, party: party, summon: summon, position: 0, main: false)
        original = last_updated_for(party)

        put "/api/v1/parties/#{party.id}/grid_summons/#{gs.id}/position",
            params: { position: 1 }.to_json,
            headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on swap' do
        other_summon = Summon.where.not(id: summon.id).first
        gs1 = create(:grid_summon, party: party, summon: summon, position: 0)
        gs2 = create(:grid_summon, party: party, summon: other_summon, position: 1)
        original = last_updated_for(party)

        post "/api/v1/parties/#{party.id}/grid_summons/swap",
             params: { source_id: gs1.id, target_id: gs2.id }.to_json,
             headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on destroy' do
        gs = create(:grid_summon, party: party, summon: summon, position: 2)
        original = last_updated_for(party)

        delete "/api/v1/grid_summons/#{gs.id}", headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to be > original
      end

      it 'bumps last_updated on duplicate' do
        summon.update!(limit: false)
        gs = create(:grid_summon, party: party, summon: summon, position: 0)
        original = last_updated_for(party)

        post "/api/v1/grid_summons/#{gs.id}/duplicate",
             params: { position: 1 }.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(last_updated_for(party)).to be > original
      end
    end
  end

  # ─────────────────────────────────────────────
  # Actions that should NOT bump last_updated
  # ─────────────────────────────────────────────

  describe 'actions that do not bump last_updated' do
    describe 'GridWeaponsController attribute-only updates' do
      it 'does not bump last_updated on update (weapon keys, AX, etc.)' do
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 2, uncap_level: 3)
        original = last_updated_for(party)

        params = {
          weapon: {
            id: gw.id, party_id: party.id, weapon_id: weapon.id,
            position: 2, mainhand: false, uncap_level: 4, transcendence_step: 0,
            element: weapon.element, weapon_key1_id: nil, weapon_key2_id: nil, weapon_key3_id: nil,
            ax_modifier1_id: nil, ax_modifier2_id: nil, ax_strength1: nil, ax_strength2: nil,
            awakening_id: nil, awakening_level: 1
          }
        }
        put "/api/v1/grid_weapons/#{gw.id}", params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end

      it 'does not bump last_updated on update_uncap_level' do
        weapon.update!(flb: true, ulb: true, transcendence: false)
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 3, uncap_level: 3)
        original = last_updated_for(party)

        params = { weapon: { id: gw.id, party_id: party.id, weapon_id: weapon.id, uncap_level: 5, transcendence_step: 0 } }
        post '/api/v1/grid_weapons/update_uncap', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'GridCharactersController attribute-only updates' do
      it 'does not bump last_updated on update (rings, perpetuity, etc.)' do
        gc = create(:grid_character, party: party, character: character, position: 2, uncap_level: 3)
        original = last_updated_for(party)

        params = {
          character: {
            id: gc.id, party_id: party.id,
            perpetuity: true
          }
        }
        put "/api/v1/grid_characters/#{gc.id}", params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end

      it 'does not bump last_updated on update_uncap_level' do
        gc = create(:grid_character, party: party, character: character, position: 2, uncap_level: 3)
        original = last_updated_for(party)

        params = { character: { id: gc.id, party_id: party.id, character_id: character.id, uncap_level: 5, transcendence_step: 0 } }
        post '/api/v1/grid_characters/update_uncap', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'GridSummonsController attribute-only updates' do
      it 'does not bump last_updated on update' do
        gs = create(:grid_summon, party: party, summon: summon, position: 2)
        original = last_updated_for(party)

        params = { summon: { id: gs.id, party_id: party.id, summon_id: summon.id, uncap_level: 4, transcendence_step: 0 } }
        put "/api/v1/grid_summons/#{gs.id}", params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end

      it 'does not bump last_updated on update_uncap_level' do
        summon.update!(flb: true, ulb: true, transcendence: false)
        gs = create(:grid_summon, party: party, summon: summon, position: 2, uncap_level: 3)
        original = last_updated_for(party)

        params = { summon: { id: gs.id, party_id: party.id, summon_id: summon.id, uncap_level: 5, transcendence_step: 0 } }
        post '/api/v1/grid_summons/update_uncap', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'PartiesController non-user-visible operations' do
      it 'does not bump last_updated on unlink_collection' do
        party.update_column(:collection_source_user_id, user.id)
        original = last_updated_for(party)

        post "/api/v1/parties/#{party.id}/unlink_collection", headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end

      it 'does not bump last_updated on sync_all' do
        create(:grid_weapon, party: party, weapon: weapon, position: 0)
        original = last_updated_for(party)

        post "/api/v1/parties/#{party.id}/sync_all", headers: headers
        expect(response).to have_http_status(:ok)

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'GridWeaponsController sync' do
      it 'does not bump last_updated on sync' do
        gw = create(:grid_weapon, party: party, weapon: weapon, position: 0)
        original = last_updated_for(party)

        # sync without a collection weapon returns 422 but does not touch last_updated
        post "/api/v1/grid_weapons/#{gw.id}/sync",
             params: { weapon: { party_id: party.id } }.to_json,
             headers: headers

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'GridCharactersController sync' do
      it 'does not bump last_updated on sync' do
        gc = create(:grid_character, party: party, character: character, position: 0)
        original = last_updated_for(party)

        post "/api/v1/grid_characters/#{gc.id}/sync",
             params: { character: { party_id: party.id } }.to_json,
             headers: headers

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'GridSummonsController sync' do
      it 'does not bump last_updated on sync' do
        gs = create(:grid_summon, party: party, summon: summon, position: 2)
        original = last_updated_for(party)

        post "/api/v1/grid_summons/#{gs.id}/sync",
             params: { summon: { party_id: party.id } }.to_json,
             headers: headers

        expect(last_updated_for(party)).to eq(original)
      end
    end

    describe 'Favorites' do
      it 'does not bump last_updated when favoriting' do
        original = last_updated_for(party)

        post '/api/v1/favorites',
             params: { favorite: { party_id: party.id } }.to_json,
             headers: headers

        expect(last_updated_for(party)).to eq(original)
      end
    end
  end

  # ─────────────────────────────────────────────
  # API serialization
  # ─────────────────────────────────────────────

  describe 'API response includes last_updated' do
    it 'exposes last_updated in the party JSON response' do
      party.update_column(:last_updated, 1.hour.ago.change(usec: 0))

      get "/api/v1/parties/#{party.shortcode}", headers: headers
      expect(response).to have_http_status(:ok)

      body = response.parsed_body['party']
      expect(body).to have_key('last_updated')
      expect(body['last_updated']).to be_present
    end
  end

  # ─────────────────────────────────────────────
  # Playlist sorting uses last_updated
  # ─────────────────────────────────────────────

  describe 'playlist party ordering' do
    it 'orders parties by last_updated within playlists' do
      playlist = create(:playlist, user: user, visibility: 1)
      old_party = create(:party, user: user, last_updated: 2.days.ago)
      new_party = create(:party, user: user, last_updated: 1.hour.ago)
      create(:playlist_party, playlist: playlist, party: old_party)
      create(:playlist_party, playlist: playlist, party: new_party)

      get "/api/v1/users/#{user.username}/playlists/#{playlist.slug}",
          headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)

      party_ids = response.parsed_body.dig('playlist', 'parties').map { |p| p['id'] }
      expect(party_ids).to eq([new_party.id, old_party.id])
    end
  end

  # ─────────────────────────────────────────────
  # Party#mark_updated! model behavior
  # ─────────────────────────────────────────────

  describe 'Party#mark_updated!' do
    it 'updates last_updated without changing updated_at' do
      original_updated_at = party.updated_at
      party.update_column(:last_updated, 1.day.ago)

      party.mark_updated!
      party.reload

      expect(party.last_updated).to be_within(2.seconds).of(Time.current)
      expect(party.updated_at).to eq(original_updated_at)
    end
  end
end
