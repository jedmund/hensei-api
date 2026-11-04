# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GW score imports', type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end
  let(:crew) { create(:crew) }
  let!(:officer) { create(:crew_membership, crew: crew, user: user, role: :captain) }
  let(:event) { create(:gw_event) }
  let(:member_user) { create(:user, granblue_id: 11_111) }
  let!(:member) { create(:crew_membership, crew: crew, user: member_user, role: :member) }
  let!(:phantom) { create(:phantom_player, crew: crew, granblue_id: '22222', name: 'Known') }

  def import(members, round: 'preliminaries', **extra)
    post '/api/v1/crew/import_gw_scores',
         params: { event_number: event.event_number, round: round, members: members, **extra }.to_json,
         headers: headers
  end

  describe 'POST /crew/import_gw_scores' do
    it 'scores members and known phantoms, and creates phantoms for unknown ids' do
      expect do
        import([{ granblue_id: 11_111, name: 'Member', score: 100 },
                { granblue_id: '22222', name: 'Known', score: 200 },
                { granblue_id: '33333', name: 'New', score: 300 }])
      end.to change(PhantomPlayer, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq('imported' => 3, 'phantoms_created' => 1, 'errors' => [])

      participation = crew.crew_gw_participations.find_by!(event: event)
      scores = participation.gw_individual_scores
      expect(scores.find_by(crew_membership: member)).to have_attributes(score: 100, is_cumulative: false,
                                                                         recorded_by_id: user.id)
      expect(scores.find_by(phantom_player: phantom).score).to eq(200)
      created = crew.phantom_players.find_by!(granblue_id: '33333')
      expect(created.name).to eq('New')
      expect(scores.find_by(phantom_player: created).score).to eq(300)
    end

    it 'creates one phantom for an unknown id that appears twice' do
      import([{ granblue_id: '44444', name: 'Twice', score: 1 },
              { granblue_id: '44444', name: 'Twice', score: 2 }], round: 'interlude')

      expect(response.parsed_body).to eq('imported' => 2, 'phantoms_created' => 1, 'errors' => [])
      expect(crew.phantom_players.where(granblue_id: '44444').count).to eq(1)
    end

    it 'updates an existing score for the round and stores is_cumulative' do
      import([{ granblue_id: 11_111, score: 100 }])
      import([{ granblue_id: 11_111, score: 150 }], is_cumulative: true)

      expect(response).to have_http_status(:created)
      score = GwIndividualScore.find_by!(crew_membership: member)
      expect(score).to have_attributes(score: 150, is_cumulative: true)
      expect(GwIndividualScore.count).to eq(1)
    end

    it 'returns multi_status with per-index errors for rows that fail' do
      import([{ granblue_id: 11_111, score: 100 }, { granblue_id: '22222', score: -5 }])

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'imported' => 1, 'phantoms_created' => 0,
        'errors' => [{ 'index' => 1, 'granblue_id' => '22222',
                       'errors' => ['Score must be greater than or equal to 0'] }]
      )
    end

    it 'returns 404 for an unknown event number' do
      post '/api/v1/crew/import_gw_scores',
           params: { event_number: 999_999, round: 'preliminaries', members: [] }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a missing or malformed members list without recording anything' do
      [{}, { members: 'x' }, { members: { granblue_id: '1' } }].each do |extra|
        post '/api/v1/crew/import_gw_scores',
             params: { event_number: event.event_number, round: 'preliminaries', **extra }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content), extra.inspect
        expect(response.parsed_body.dig('errors', 'param')).to eq('members')
      end
      expect(CrewGwParticipation.count).to eq(0)
    end

    it 'refuses a regular member' do
      officer.update!(role: :member)

      import([{ granblue_id: 11_111, score: 100 }])

      expect(response).to have_http_status(:unauthorized)
      expect(GwIndividualScore.count).to eq(0)
    end

    it 'refuses a user without a crew' do
      officer.destroy!

      import([{ granblue_id: 11_111, score: 100 }])

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'requires authentication' do
      post '/api/v1/crew/import_gw_scores', params: { event_number: event.event_number }.to_json,
                                            headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /crew/preview_gw_phantoms' do
    it 'sorts ids into existing and new phantoms, skipping members' do
      post '/api/v1/crew/preview_gw_phantoms',
           params: { granblue_ids: ['11111', '22222', 33_333] }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('existing_phantom_ids' => ['22222'], 'new_phantom_ids' => ['33333'])
    end

    it 'refuses a missing or malformed id list' do
      [{}, { granblue_ids: '22222' }].each do |params|
        post '/api/v1/crew/preview_gw_phantoms', params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content), params.inspect
        expect(response.parsed_body.dig('errors', 'param')).to eq('granblue_ids')
      end
    end
  end
end
