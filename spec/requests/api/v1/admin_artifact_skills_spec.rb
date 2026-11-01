# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin artifact skills collection', type: :request do
  let(:path) { '/api/v1/admin/artifact_skills' }
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

  let!(:atk) do
    create(:artifact_skill, skill_group: :group_i, modifier: 1, name_en: 'ATK', name_jp: '攻撃力',
                            score_category: 1, base_values: [1320, 1440, 1560, 1680, 1800], growth: 300)
  end
  let!(:hp) do
    create(:artifact_skill, skill_group: :group_i, modifier: 2, name_en: 'HP', name_jp: 'HP',
                            score_category: 2, base_values: [660, 720, 780, 840, 900], growth: 150)
  end
  let!(:dispel) do
    create(:artifact_skill, skill_group: :group_ii, modifier: 20, name_en: 'Chance to cancel incoming dispels',
                            name_jp: 'ディスペル無効', game_name_en: 'Dispel Cancel', score_category: 3,
                            base_values: [20], growth: 20)
  end
  let!(:flurry) do
    create(:artifact_skill, skill_group: :group_iii, modifier: 20, name_en: 'Gain Flurry after hitting a foe',
                            name_jp: '連撃', polarity: :negative, score_category: nil,
                            base_values: [], growth: nil, suffix_en: '%')
  end

  before do
    ArtifactSkill.where.not(id: [atk, hp, dispel, flurry].map(&:id)).delete_all
  end

  describe 'access' do
    it 'returns results for an editor with the default fields, by group then modifier' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['ATK', 'HP', 'Chance to cancel incoming dispels', 'Gain Flurry after hitting a foe'])
      expect(body['results'].first.keys).to match_array(
        %w[id skill_group modifier name_en name_jp game_name_en game_name_jp polarity base_values suffix_en suffix_jp]
      )
      expect(body['results'].first).to include('skill_group' => 'group_i', 'polarity' => 'positive',
                                               'base_values' => [1320, 1440, 1560, 1680, 1800])
    end

    it 'sends growth as a number and the score category as its integer' do
      body = fetch(fields: 'growth,score_category')
      expect(body['results'].map { |r| [r['growth'], r['score_category']] })
        .to eq([[300.0, 1], [150.0, 2], [20.0, 3], [nil, nil]])
    end

    it 'rejects a signed-in user below the editor role' do
      fetch({}, auth_headers(create(:user, role: 3)))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed-out request' do
      fetch({}, {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'q and filters' do
    it 'matches display and game names' do
      fetch(q: 'dispel cancel')
      expect(names).to eq(['Chance to cancel incoming dispels'])
      fetch(q: '攻撃')
      expect(names).to eq(['ATK'])
    end

    it 'filters by group, polarity, score category (or none) and last edited' do
      fetch(filter: { skill_group: 'group_ii,group_iii' })
      expect(names).to eq(['Chance to cancel incoming dispels', 'Gain Flurry after hitting a foe'])
      fetch(filter: { polarity: 'negative' })
      expect(names).to eq(['Gain Flurry after hitting a foe'])
      fetch(filter: { score_category: '2,none' })
      expect(names).to eq(['HP', 'Gain Flurry after hitting a foe'])

      hp.update_columns(updated_at: 2.weeks.ago)
      fetch(filter: { updated_at: { lte: 1.week.ago.to_date.iso8601 } })
      expect(names).to eq(['HP'])
    end

    it 'rejects a score category given by name' do
      fetch(filter: { score_category: 'attack' })
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'sort and facets' do
    it 'sorts by any published column' do
      fetch(sort: '-modifier,name_en')
      expect(names).to eq(['Chance to cancel incoming dispels', 'Gain Flurry after hitting a foe', 'HP', 'ATK'])
      fetch(sort: '-growth')
      expect(names.last).to eq('Gain Flurry after hitting a foe')
    end

    it 'counts groups by name, polarities and score categories' do
      body = fetch(facets: 'skill_group,polarity,score_category')
      expect(body['facets']['skill_group']).to eq('group_i' => 2, 'group_ii' => 1, 'group_iii' => 1)
      expect(body['facets']['polarity']).to eq('positive' => 3, 'negative' => 1)
      expect(body['facets']['score_category']).to eq('1' => 1, '2' => 1, '3' => 1, 'none' => 1)
    end
  end

  describe 'conditional GET' do
    it 'returns 304 for an unchanged collection and 200 after an edit' do
      fetch
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      hp.update!(name_jp: 'HP上昇')
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
