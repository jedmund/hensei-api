# frozen_string_literal: true

require 'rails_helper'

# Edge cases of claiming anonymous parties (POST /parties/migrate) and of
# previewing the claim (POST /parties/preview_migrate). The common paths are
# in parties_spec.rb.
RSpec.describe 'Party migration', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let!(:anon_party) { create(:party, user: nil, name: 'Anon') }

  before { anon_party.update_columns(edit_key: 'key1') }

  def too_many_entries
    Array.new(101) { |i| { shortcode: "CODE#{i}", edit_key: 'k' } }
  end

  describe 'POST /api/v1/parties/migrate' do
    def migrate(entries)
      post '/api/v1/parties/migrate', params: { parties: entries }.to_json, headers: headers
    end

    it 'claims a party addressed by its id and echoes the identifier' do
      migrate([{ shortcode: anon_party.id, edit_key: 'key1' }])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'results' => [{ 'shortcode' => anon_party.id, 'status' => 'migrated' }],
        'migrated_count' => 1
      )
      expect(anon_party.reload.user_id).to eq(user.id)
    end

    it 'reports each entry of a mixed batch in order' do
      own_party = create(:party, user: user)

      migrate([
                { shortcode: 'NOPE99', edit_key: 'x' },
                { shortcode: anon_party.shortcode, edit_key: 'wrong' },
                { shortcode: own_party.shortcode, edit_key: '' },
                { shortcode: anon_party.shortcode, edit_key: 'key1' }
              ])

      expect(response.parsed_body['results'].pluck('status'))
        .to eq(%w[not_found invalid_key already_claimed migrated])
      expect(response.parsed_body['migrated_count']).to eq(1)
    end

    it 'treats a missing edit key as invalid' do
      migrate([{ shortcode: anon_party.shortcode }])

      expect(response.parsed_body['results'].first['status']).to eq('invalid_key')
      expect(anon_party.reload.user_id).to be_nil
    end

    it 'trims whitespace around the edit key' do
      migrate([{ shortcode: anon_party.shortcode, edit_key: "  key1\n" }])

      expect(response.parsed_body['results'].first['status']).to eq('migrated')
    end

    it 'refuses more than 100 entries and changes nothing' do
      migrate(too_many_entries + [{ shortcode: anon_party.shortcode, edit_key: 'key1' }])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Too many parties (max 100)')
      expect(anon_party.reload.user_id).to be_nil
    end

    it 'keeps deposited keys for parties it could not claim' do
      user.user_edit_keys.create!(edit_key: 'wrong', shortcode: anon_party.shortcode)
      user.user_edit_keys.create!(edit_key: 'x', shortcode: 'NOPE99')

      post '/api/v1/parties/migrate', params: {}.to_json, headers: headers

      expect(response.parsed_body['migrated_count']).to eq(0)
      expect(user.user_edit_keys.pluck(:shortcode)).to contain_exactly(anon_party.shortcode, 'NOPE99')
    end

    it "drops a deposited key for the user's own claimed party" do
      own_party = create(:party, user: user)
      user.user_edit_keys.create!(edit_key: 'x', shortcode: own_party.shortcode)

      post '/api/v1/parties/migrate', params: {}.to_json, headers: headers

      expect(response.parsed_body['results'].first['status']).to eq('already_claimed')
      expect(user.user_edit_keys.count).to eq(0)
    end

    it "doesn't claim with someone else's deposited key" do
      other = create(:user)
      other.user_edit_keys.create!(edit_key: 'key1', shortcode: anon_party.shortcode)

      post '/api/v1/parties/migrate', params: {}.to_json, headers: headers

      expect(response.parsed_body).to eq('results' => [], 'migrated_count' => 0)
      expect(anon_party.reload.user_id).to be_nil
      expect(other.user_edit_keys.count).to eq(1)
    end
  end

  describe 'POST /api/v1/parties/preview_migrate' do
    def preview(entries)
      post '/api/v1/parties/preview_migrate', params: { parties: entries }.to_json, headers: headers
    end

    it 'previews a party addressed by its id' do
      preview([{ shortcode: anon_party.id, edit_key: 'key1' }])

      entry = response.parsed_body['parties'].first
      expect(entry['status']).to eq('ready')
      expect(entry['party']['shortcode']).to eq(anon_party.shortcode)
    end

    it 'lists a party once when it is named by both shortcode and id' do
      preview([
                { shortcode: anon_party.shortcode, edit_key: 'key1' },
                { shortcode: anon_party.id, edit_key: 'key1' },
                { shortcode: 'NOPE99', edit_key: 'x' },
                { shortcode: 'NOPE99', edit_key: 'x' }
              ])

      expect(response.parsed_body['parties'].pluck('status')).to eq(%w[ready not_found not_found])
    end

    it 'uses the deposited keys and leaves them in place' do
      user.user_edit_keys.create!(edit_key: 'key1', shortcode: anon_party.shortcode)

      post '/api/v1/parties/preview_migrate', params: {}.to_json, headers: headers

      expect(response.parsed_body['parties'].pluck('status')).to eq(['ready'])
      expect(user.user_edit_keys.count).to eq(1)
      expect(anon_party.reload.user_id).to be_nil
    end

    it 'returns an empty list with nothing to preview' do
      post '/api/v1/parties/preview_migrate', params: {}.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('parties' => [])
    end

    it 'refuses more than 100 entries' do
      preview(too_many_entries)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'Too many parties (max 100)')
    end

    it 'renders the preview view of the party' do
      preview([{ shortcode: anon_party.shortcode, edit_key: 'key1' }])

      party_json = response.parsed_body['parties'].first['party']
      expect(party_json).to include('id' => anon_party.id, 'name' => 'Anon', 'shortcode' => anon_party.shortcode)
      expect(party_json).not_to have_key('edit_key')
    end
  end
end
