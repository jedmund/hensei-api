require 'rails_helper'

RSpec.describe 'Api::V1::GwIndividualScores', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }
  let(:gw_event) { create(:gw_event) }
  let!(:participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }

  describe 'POST /api/v1/crew/gw_participations/:gw_participation_id/individual_scores' do
    let(:valid_params) do
      {
        individual_score: {
          crew_membership_id: membership.id,
          round: 'preliminaries',
          score: 1_000_000
        }
      }
    end

    context 'as crew officer' do
      it 'creates an individual score' do
        expect {
          post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores",
               params: valid_params,
               headers: auth_headers
        }.to change(GwIndividualScore, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['individual_score']['score']).to eq(1_000_000)
        expect(json['individual_score']['round']).to eq('preliminaries')
      end

      it 'can record score for other members' do
        other_user = create(:user)
        other_membership = create(:crew_membership, crew: crew, user: other_user, role: :member)

        params = {
          individual_score: {
            crew_membership_id: other_membership.id,
            round: 'preliminaries',
            score: 500_000
          }
        }

        post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores",
             params: params,
             headers: auth_headers

        expect(response).to have_http_status(:created)
      end

      it 'returns error for duplicate round per member' do
        create(:gw_individual_score,
               crew_gw_participation: participation,
               crew_membership: membership,
               round: :preliminaries)

        post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores",
             params: valid_params,
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'can record own score' do
        post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores",
             params: valid_params,
             headers: auth_headers

        expect(response).to have_http_status(:created)
      end

      it 'cannot record score for other members' do
        other_user = create(:user)
        other_membership = create(:crew_membership, crew: crew, user: other_user, role: :member)

        params = {
          individual_score: {
            crew_membership_id: other_membership.id,
            round: 'preliminaries',
            score: 500_000
          }
        }

        post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores",
             params: params,
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/crew/gw_participations/:gw_participation_id/individual_scores/:id' do
    let!(:score) do
      create(:gw_individual_score,
             crew_gw_participation: participation,
             crew_membership: membership,
             round: :preliminaries,
             score: 1_000_000)
    end

    context 'as crew officer' do
      it 'updates the score' do
        put "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/#{score.id}",
            params: { individual_score: { score: 2_000_000 } },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['individual_score']['score']).to eq(2_000_000)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'can update own score' do
        put "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/#{score.id}",
            params: { individual_score: { score: 2_000_000 } },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
      end

      it 'cannot update other member scores' do
        other_user = create(:user)
        other_membership = create(:crew_membership, crew: crew, user: other_user, role: :member)
        other_score = create(:gw_individual_score,
                             crew_gw_participation: participation,
                             crew_membership: other_membership,
                             round: :finals_day_1)

        put "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/#{other_score.id}",
            params: { individual_score: { score: 2_000_000 } },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/crew/gw_participations/:gw_participation_id/individual_scores/:id' do
    let!(:score) do
      create(:gw_individual_score,
             crew_gw_participation: participation,
             crew_membership: membership)
    end

    context 'as crew officer' do
      it 'deletes the score' do
        expect {
          delete "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/#{score.id}",
                 headers: auth_headers
        }.to change(GwIndividualScore, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'can delete own score' do
        expect {
          delete "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/#{score.id}",
                 headers: auth_headers
        }.to change(GwIndividualScore, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'cannot delete other member scores' do
        other_user = create(:user)
        other_membership = create(:crew_membership, crew: crew, user: other_user, role: :member)
        other_score = create(:gw_individual_score,
                             crew_gw_participation: participation,
                             crew_membership: other_membership)

        delete "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/#{other_score.id}",
               headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crew/gw_participations/:gw_participation_id/individual_scores/batch' do
    let(:other_user) { create(:user) }
    let!(:other_membership) { create(:crew_membership, crew: crew, user: other_user, role: :member) }

    context 'as crew officer' do
      it 'creates multiple scores' do
        params = {
          scores: [
            { crew_membership_id: membership.id, round: 'preliminaries', score: 1_000_000 },
            { crew_membership_id: other_membership.id, round: 'preliminaries', score: 500_000 }
          ]
        }

        expect {
          post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/batch",
               params: params,
               headers: auth_headers
        }.to change(GwIndividualScore, :count).by(2)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['individual_scores'].length).to eq(2)
      end

      it 'updates existing scores in batch' do
        existing = create(:gw_individual_score,
                          crew_gw_participation: participation,
                          crew_membership: membership,
                          round: :preliminaries,
                          score: 100_000)

        params = {
          scores: [
            { crew_membership_id: membership.id, round: 'preliminaries', score: 2_000_000 }
          ]
        }

        expect {
          post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/batch",
               params: params,
               headers: auth_headers
        }.not_to change(GwIndividualScore, :count)

        expect(response).to have_http_status(:created)
        expect(existing.reload.score).to eq(2_000_000)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        params = {
          scores: [
            { crew_membership_id: membership.id, round: 'preliminaries', score: 1_000_000 }
          ]
        }

        post "/api/v1/crew/gw_participations/#{participation.id}/individual_scores/batch",
             params: params,
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
