require 'rails_helper'

RSpec.describe 'Api::V1::CrewGwParticipations', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }
  let(:gw_event) { create(:gw_event) }

  describe 'POST /api/v1/gw_events/:id/participations' do
    context 'as crew officer' do
      it 'joins the crew to an event' do
        expect {
          post "/api/v1/gw_events/#{gw_event.id}/participations", headers: auth_headers
        }.to change(CrewGwParticipation, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'returns error if already participating' do
        create(:crew_gw_participation, crew: crew, gw_event: gw_event)

        post "/api/v1/gw_events/#{gw_event.id}/participations", headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        post "/api/v1/gw_events/#{gw_event.id}/participations", headers: auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without a crew' do
      let!(:membership) { nil }

      it 'returns unprocessable_entity' do
        post "/api/v1/gw_events/#{gw_event.id}/participations", headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('not_in_crew')
      end
    end
  end

  describe 'GET /api/v1/crew/gw_participations' do
    let!(:participation1) { create(:crew_gw_participation, crew: crew) }
    let!(:participation2) { create(:crew_gw_participation, crew: crew) }
    let!(:other_participation) { create(:crew_gw_participation) }

    it 'returns crew participations' do
      get '/api/v1/crew/gw_participations', headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['crew_gw_participations'].length).to eq(2)
    end

    context 'without a crew' do
      let!(:membership) { nil }
      let!(:participation1) { nil }
      let!(:participation2) { nil }

      it 'returns unprocessable_entity' do
        get '/api/v1/crew/gw_participations', headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/crew/gw_participations/:id' do
    let!(:participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }

    it 'returns the participation' do
      get "/api/v1/crew/gw_participations/#{participation.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['crew_gw_participation']['id']).to eq(participation.id)
    end

    it 'returns 404 for other crew participation' do
      other_participation = create(:crew_gw_participation)
      get "/api/v1/crew/gw_participations/#{other_participation.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/crew/gw_participations/by_event/:event_id' do
    context 'when participating in the event' do
      let!(:participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }

      it 'returns the event and participation by event ID' do
        get "/api/v1/crew/gw_participations/by_event/#{gw_event.id}", headers: auth_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['gw_event']['id']).to eq(gw_event.id)
        expect(json['crew_gw_participation']['id']).to eq(participation.id)
        expect(json['members_during_event']).to be_an(Array)
      end

      it 'returns the event and participation by event number' do
        get "/api/v1/crew/gw_participations/by_event/#{gw_event.event_number}", headers: auth_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['gw_event']['id']).to eq(gw_event.id)
        expect(json['crew_gw_participation']['id']).to eq(participation.id)
      end

      it 'includes members who were active during the event' do
        get "/api/v1/crew/gw_participations/by_event/#{gw_event.id}", headers: auth_headers
        json = JSON.parse(response.body)
        member_ids = json['members_during_event'].map { |m| m['id'] }
        expect(member_ids).to include(membership.id)
      end
    end

    context 'when not participating in the event' do
      it 'returns event but null participation' do
        get "/api/v1/crew/gw_participations/by_event/#{gw_event.id}", headers: auth_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['gw_event']['id']).to eq(gw_event.id)
        expect(json['crew_gw_participation']).to be_nil
      end
    end

    context 'when event does not exist' do
      it 'returns null for both' do
        get '/api/v1/crew/gw_participations/by_event/99999', headers: auth_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['gw_event']).to be_nil
        expect(json['crew_gw_participation']).to be_nil
      end
    end

    context 'without a crew' do
      let!(:membership) { nil }

      it 'returns unprocessable_entity' do
        get "/api/v1/crew/gw_participations/by_event/#{gw_event.id}", headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT /api/v1/crew/gw_participations/:id' do
    let!(:participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }

    context 'as officer' do
      it 'updates rankings' do
        put "/api/v1/crew/gw_participations/#{participation.id}",
            params: { crew_gw_participation: { preliminary_ranking: 1500, final_ranking: 1200 } },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['crew_gw_participation']['preliminary_ranking']).to eq(1500)
        expect(json['crew_gw_participation']['final_ranking']).to eq(1200)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        put "/api/v1/crew/gw_participations/#{participation.id}",
            params: { crew_gw_participation: { preliminary_ranking: 1500 } },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
