require 'rails_helper'

RSpec.describe 'Api::V1::GwCrewScores', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }
  let(:gw_event) { create(:gw_event) }
  let!(:participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }

  describe 'POST /api/v1/crew/gw_participations/:gw_participation_id/crew_scores' do
    let(:valid_params) do
      {
        crew_score: {
          round: 'preliminaries',
          crew_score: 5_000_000
        }
      }
    end

    context 'as crew officer' do
      it 'creates a crew score' do
        expect {
          post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
               params: valid_params,
               headers: auth_headers
        }.to change(GwCrewScore, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['gw_crew_score']['round']).to eq('preliminaries')
        expect(json['gw_crew_score']['crew_score']).to eq(5_000_000)
      end

      it 'creates a score with opponent info' do
        params = {
          crew_score: {
            round: 'finals_day_1',
            crew_score: 10_000_000,
            opponent_score: 8_000_000,
            opponent_name: 'Rival Crew',
            opponent_granblue_id: '12345678'
          }
        }

        post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
             params: params,
             headers: auth_headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['gw_crew_score']['opponent_name']).to eq('Rival Crew')
        expect(json['gw_crew_score']['victory']).to be true
      end

      it 'returns error for duplicate round' do
        create(:gw_crew_score, crew_gw_participation: participation, round: :preliminaries)

        post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
             params: valid_params,
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
             params: valid_params,
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/crew/gw_participations/:gw_participation_id/crew_scores/:id' do
    let!(:score) { create(:gw_crew_score, crew_gw_participation: participation, round: :preliminaries, crew_score: 1_000_000) }

    context 'as crew officer' do
      it 'updates the score' do
        put "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
            params: { crew_score: { crew_score: 2_000_000 } },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['gw_crew_score']['crew_score']).to eq(2_000_000)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        put "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
            params: { crew_score: { crew_score: 2_000_000 } },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/crew/gw_participations/:gw_participation_id/crew_scores/:id' do
    let!(:score) { create(:gw_crew_score, crew_gw_participation: participation) }

    context 'as crew officer' do
      it 'deletes the score' do
        expect {
          delete "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
                 headers: auth_headers
        }.to change(GwCrewScore, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        delete "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
               headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
