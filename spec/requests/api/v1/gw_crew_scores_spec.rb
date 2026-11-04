require 'rails_helper'

RSpec.describe 'Api::V1::GwCrewScores', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let(:user_role) { :captain }
  let(:gw_event) { create(:gw_event) }
  let(:participation) { create(:crew_gw_participation, crew: crew, event: gw_event) }

  before do
    create(:crew_membership, crew: crew, user: user, role: user_role)
    participation
  end

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
        expect do
          post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
               params: valid_params,
               headers: auth_headers
        end.to change(GwCrewScore, :count).by(1)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['gw_crew_score']['round']).to eq(0)
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
        json = response.parsed_body
        expect(json['gw_crew_score']['opponent_name']).to eq('Rival Crew')
        expect(json['gw_crew_score']['victory']).to be true
      end

      it 'returns error for duplicate round' do
        create(:gw_crew_score, crew_gw_participation: participation, round: :preliminaries)

        expect do
          post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
               params: valid_params,
               headers: auth_headers
        end.not_to change(GwCrewScore, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'as regular member' do
      let(:user_role) { :member }

      it 'returns unauthorized' do
        expect do
          post "/api/v1/crew/gw_participations/#{participation.id}/crew_scores",
               params: valid_params,
               headers: auth_headers
        end.not_to change(GwCrewScore, :count)

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
        json = response.parsed_body
        expect(json['gw_crew_score']['crew_score']).to eq(2_000_000)
      end
    end

    context 'as regular member' do
      let(:user_role) { :member }

      it 'returns unauthorized' do
        put "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
            params: { crew_score: { crew_score: 2_000_000 } },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
        expect(score.reload.crew_score).to eq(1_000_000)
      end
    end
  end

  describe 'DELETE /api/v1/crew/gw_participations/:gw_participation_id/crew_scores/:id' do
    let!(:score) { create(:gw_crew_score, crew_gw_participation: participation) }

    context 'as crew officer' do
      it 'deletes the score' do
        expect do
          delete "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
                 headers: auth_headers
        end.to change(GwCrewScore, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as regular member' do
      let(:user_role) { :member }

      it 'returns unauthorized' do
        expect do
          delete "/api/v1/crew/gw_participations/#{participation.id}/crew_scores/#{score.id}",
                 headers: auth_headers
        end.not_to change(GwCrewScore, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
