# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin refreshes', :refresh_redis, type: :request do
  let(:path) { '/api/v1/admin/refreshes' }
  let(:curator_headers) { auth_headers(create(:user, role: 6)) }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  before { travel_to Time.utc(2026, 10, 10, 3) }

  describe 'access' do
    it 'refuses plain users and anonymous requests, and changes nothing' do
      allow(HomeFeed).to receive(:expire)
      [auth_headers(create(:user, role: 5)), {}].each do |headers|
        get path, headers: headers
        expect(response).to have_http_status(:unauthorized)
        post "#{path}/home", headers: headers
        expect(response).to have_http_status(:unauthorized)
        post "#{path}/gacha", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
      expect(HomeFeed).not_to have_received(:expire)
      expect(GachaSimulation::Refresh.refetch_requested_at).to be_nil
    end

    it 'serves editors too' do
      get path, headers: auth_headers(create(:user, role: 7))
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /admin/refreshes' do
    it 'shows the current banner and no waiting request' do
      GachaSimulation::BannerImport.call(gacha_banner_payload)
      get path, headers: curator_headers
      expect(response.parsed_body).to eq(
        'home' => { 'cache_seconds' => 300 },
        'gacha' => {
          'banner' => { 'game_id' => '211960', 'name' => gacha_banner_payload['banner']['name'],
                        'starts_at' => '2026-10-09T10:00:00.000Z', 'ends_at' => '2026-10-12T10:00:00.000Z',
                        'fetched_at' => '2026-10-10T03:00:00.000Z', 'live' => true },
          'refetch_requested_at' => nil
        }
      )
    end
  end

  describe 'POST /admin/refreshes/home' do
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original
    end

    def new_battle_names
      get '/api/v1/home'
      response.parsed_body['new_battles'].map { |battle| battle.dig('raid', 'name', 'en') }
    end

    it 'shows changes Home would otherwise keep for 5 minutes' do
      expect(new_battle_names).to be_empty
      # New raids don't expire Home themselves
      create(:raid, name_en: 'Fresh Raid', released_at: Date.new(2026, 10, 1))
      expect(new_battle_names).to be_empty

      post "#{path}/home", headers: curator_headers
      expect(response).to have_http_status(:ok)
      expect(new_battle_names).to eq(['Fresh Raid'])
    end
  end

  describe 'POST /admin/refreshes/gacha' do
    it 'records a re-fetch request and changes the catalogue epoch' do
      epoch = GachaSimulation::Refresh.catalogue_epoch
      post "#{path}/gacha", headers: curator_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('gacha', 'refetch_requested_at')).to eq('2026-10-10T03:00:00.000Z')
      expect(GachaSimulation::Refresh.catalogue_epoch).to eq(epoch + 1)
    end
  end
end
