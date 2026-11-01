# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin raid groups collection', type: :request do
  let(:path) { '/api/v1/admin/raid_groups' }
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  def fetch(params = {}, headers = editor_headers)
    get path, params: params, headers: headers
    response.parsed_body
  end

  def names(body = response.parsed_body)
    body['results'].map { |r| r['name_en'] }
  end

  let!(:omega) do
    create(:raid_group, name_en: 'Omega', name_jp: 'マグナ', section: 1, order: 2, difficulty: 3, hl: false)
  end
  let!(:primarchs) do
    create(:raid_group, name_en: 'Primarchs', name_jp: '四大天司', section: 1, order: 1, difficulty: 6, hl: true,
                        guidebooks: true)
  end
  let!(:farming) do
    create(:raid_group, name_en: 'Farming', name_jp: '素材', section: 0, order: 0, difficulty: nil, hl: false,
                        support_summon: false)
  end

  before do
    # Drop groups other data seeds (rolled back after each example) so counts are exact.
    Character.where.not(solomonis_zone_id: nil).update_all(solomonis_zone_id: nil)
    EventRaid.delete_all
    Raid.delete_all
    RaidGroup.where.not(id: [omega, primarchs, farming].map(&:id)).delete_all
    create(:raid, group: omega, player_count: 30)
    create(:raid, group: omega, player_count: 6)
    create(:raid, group: omega, player_count: 30)
    create(:raid, group: primarchs, player_count: 6)
  end

  describe 'access' do
    it 'returns results for an editor with the default fields, by section and order' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(%w[Farming Primarchs Omega])
      expect(body['results'].first.keys).to match_array(
        %w[id name_en name_jp section order difficulty hl extra guidebooks unlimited support_summon raid_count
           player_counts]
      )
    end

    it 'counts raids and lists their distinct party sizes' do
      body = fetch
      omega_row = body['results'].find { |r| r['id'] == omega.id }
      expect(omega_row).to include('raid_count' => 3, 'player_counts' => [6, 30])
      expect(body['results'].first).to include('raid_count' => 0, 'player_counts' => [])
    end

    it 'rejects a signed-in user below the editor role' do
      fetch({}, auth_headers(create(:user, role: 6)))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed-out request' do
      fetch({}, {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'q' do
    it 'matches English and Japanese names' do
      fetch(q: 'ome')
      expect(names).to eq(%w[Omega])
      fetch(q: '四大')
      expect(names).to eq(%w[Primarchs])
    end
  end

  describe 'filters' do
    it 'filters by section and difficulty' do
      fetch(filter: { section: '0' })
      expect(names).to eq(%w[Farming])
      fetch(filter: { difficulty: '3,none' })
      expect(names).to eq(%w[Farming Omega])
    end

    it 'filters by booleans' do
      fetch(filter: { hl: 'true' })
      expect(names).to eq(%w[Primarchs])
      fetch(filter: { guidebooks: 'false', support_summon: 'true' })
      expect(names).to eq(%w[Omega])
    end
  end

  describe 'sort' do
    it 'sorts by difficulty, nulls last' do
      fetch(sort: '-difficulty')
      expect(names).to eq(%w[Primarchs Omega Farming])
    end
  end

  describe 'facets' do
    it 'counts sections and difficulties' do
      body = fetch(filter: { section: '1' }, facets: 'section,difficulty')
      expect(body['facets']['section']).to eq('0' => 1, '1' => 2)
      expect(body['facets']['difficulty']).to eq('3' => 1, '6' => 1)
    end
  end

  describe 'conditional GET' do
    it 'returns 200 after a raid moves group' do
      fetch
      etag = response.headers['ETag']
      travel(1.second) { create(:raid, group: farming) }
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
