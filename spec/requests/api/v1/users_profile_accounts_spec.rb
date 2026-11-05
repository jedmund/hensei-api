# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile account fields', type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def update(attrs)
    put '/api/v1/users/me', params: { user: attrs }.to_json, headers: headers
  end

  it 'rejects Granblue IDs under three digits' do
    original = user.granblue_id
    [0, 7, 99].each do |id|
      update(granblue_id: id)
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(user.reload.granblue_id).to eq(original)

    update(granblue_id: 100)
    expect(user.reload.granblue_id).to eq(100)
  end

  it 'stores a pasted channel URL as its handle' do
    update(youtube: 'https://www.youtube.com/@SlyIIBoT')
    expect(response).to have_http_status(:ok)
    expect(user.reload.youtube).to eq('@SlyIIBoT')
  end

  it 'rejects YouTube values that are not a channel' do
    update(youtube: 'https://www.youtube.com/watch?v=abc')
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.youtube).to be_nil
  end

  it 'stores a pasted wiki user page as the username' do
    update(wiki_profile: 'https://gbf.wiki/User:ItsJustSly')
    expect(response).to have_http_status(:ok)
    expect(user.reload.wiki_profile).to eq('ItsJustSly')
  end

  it 'rejects wiki pages that are not a user page' do
    update(wiki_profile: 'https://gbf.wiki/Siero')
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'clears the accounts when sent empty' do
    user.update!(granblue_id: 12_345_678, youtube: '@someone', wiki_profile: 'Someone')
    update(granblue_id: '', youtube: '', wiki_profile: '')
    expect(user.reload).to have_attributes(granblue_id: nil, youtube: nil, wiki_profile: nil)
  end
end
