# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PartyStickers', type: :request do
  let(:owner) { create(:user) }
  let(:giver) { create(:user) }
  let(:party) { create(:party, user: owner, visibility: 1) }
  let!(:sticker) { create(:sticker, slug: 'cleared') }
  let!(:other_sticker) { create(:sticker, slug: 'fast') }
  let(:headers) { bearer_headers(giver) }

  def json_response
    JSON.parse(response.body)
  end

  describe 'PUT /api/v1/parties/:id/sticker' do
    it 'gives a sticker to a public party' do
      expect do
        put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }, headers: headers
      end.to change(PartySticker, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('sticker' => 'cleared')
      expect(PartySticker.last).to have_attributes(user_id: giver.id, party_id: party.id, sticker_id: sticker.id)
    end

    it 'replaces the sticker instead of adding a second one' do
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }, headers: headers

      expect do
        put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'fast' }, headers: headers
      end.not_to change(PartySticker, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response['sticker']).to eq('fast')
      expect(PartySticker.find_by(user: giver, party: party).sticker).to eq(other_sticker)
    end

    it 'enqueues a participation recompute for the party' do
      expect do
        put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }, headers: headers
      end.to have_enqueued_job(PartyParticipation::ScoreJob).with(party.id)
    end

    it 'returns 401 when signed out' do
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 for your own party' do
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }, headers: bearer_headers(owner)
      expect(response).to have_http_status(:forbidden)
      expect(PartySticker.count).to eq(0)
    end

    it 'returns 422 for an unlisted party' do
      party.update!(visibility: 2)
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for a private party' do
      party.update!(visibility: 3)
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'cleared' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(PartySticker.count).to eq(0)
    end

    it 'lets an edit-key party (no owner) receive stickers' do
      anonymous = create(:party, user: nil, visibility: 1)
      put "/api/v1/parties/#{anonymous.id}/sticker", params: { sticker: 'cleared' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(anonymous.party_stickers.count).to eq(1)
    end

    it 'returns 422 for an inactive sticker' do
      create(:sticker, :inactive, slug: 'retired')
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'retired' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 for an unknown sticker' do
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'nope' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 404 for an unknown party or a shortcode' do
      put '/api/v1/parties/00000000-0000-0000-0000-000000000000/sticker', params: { sticker: 'cleared' }, headers: headers
      expect(response).to have_http_status(:not_found)

      put "/api/v1/parties/#{party.shortcode}/sticker", params: { sticker: 'cleared' }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'ignores user_id and party_id in the body' do
      other_party = create(:party, visibility: 1)
      put "/api/v1/parties/#{party.id}/sticker",
          params: { sticker: 'cleared', user_id: owner.id, party_id: other_party.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(PartySticker.sole).to have_attributes(user_id: giver.id, party_id: party.id)
    end

    it "cannot change another user's sticker" do
      theirs = create(:party_sticker, party: party, sticker: sticker)
      put "/api/v1/parties/#{party.id}/sticker", params: { sticker: 'fast', user_id: theirs.user_id }, headers: headers

      expect(theirs.reload.sticker).to eq(sticker)
      expect(PartySticker.find_by(user: giver, party: party).sticker).to eq(other_sticker)
    end
  end

  describe 'DELETE /api/v1/parties/:id/sticker' do
    it 'removes your sticker' do
      create(:party_sticker, user: giver, party: party, sticker: sticker)
      expect do
        delete "/api/v1/parties/#{party.id}/sticker", headers: headers
      end.to change(PartySticker, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'returns 204 when you had no sticker' do
      delete "/api/v1/parties/#{party.id}/sticker", headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it "only ever removes your own sticker, never another user's" do
      theirs = create(:party_sticker, party: party, sticker: sticker)
      delete "/api/v1/parties/#{party.id}/sticker", params: { user_id: theirs.user_id }, headers: headers

      expect(response).to have_http_status(:no_content)
      expect(PartySticker.exists?(theirs.id)).to be(true)
    end

    it 'returns 401 when signed out' do
      delete "/api/v1/parties/#{party.id}/sticker"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
