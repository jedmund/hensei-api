# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin job skills collection', type: :request do
  let(:path) { '/api/v1/admin/job_skills' }
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

  let!(:berserker) { create(:job, name_en: 'Berserker', name_jp: 'ベルセルク') }
  let!(:sage) { create(:job, name_en: 'Sage', name_jp: 'セージ') }
  let!(:rage) do
    create(:job_skill, job: berserker, name_en: 'Rage IV', name_jp: 'レイジIV', slug: 'rage-iv', color: 2,
                       main: true, sub: true, order: 1)
  end
  let!(:armor_break) do
    create(:job_skill, job: berserker, name_en: 'Armor Break', name_jp: 'アーマーブレイク', slug: 'armor-break',
                       color: 2, emp: true, order: 2)
  end
  let!(:veil) do
    create(:job_skill, job: sage, name_en: 'Veil', name_jp: 'ヴェール', slug: 'veil', color: 3, main: true,
                       order: 1)
  end

  before do
    JobAccessory.delete_all
    JobSkill.where.not(id: [rage, armor_break, veil].map(&:id)).delete_all
  end

  describe 'access' do
    it 'returns results for an editor with the default fields and sort' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['Armor Break', 'Rage IV', 'Veil'])
      expect(body['results'].first.keys).to match_array(
        %w[id name_en name_jp slug color main sub emp base order job updated_at]
      )
      expect(body['results'].first['job']).to eq(
        'id' => berserker.id, 'granblue_id' => berserker.granblue_id, 'name_en' => 'Berserker', 'name_jp' => 'ベルセルク'
      )
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
    it 'matches names and slugs' do
      fetch(q: 'armor-b')
      expect(names).to eq(['Armor Break'])
      fetch(q: 'ヴェール')
      expect(names).to eq(['Veil'])
    end

    it 'filters by job, colour and skill kind' do
      fetch(filter: { job: sage.id })
      expect(names).to eq(['Veil'])
      fetch(filter: { color: '2' })
      expect(names).to eq(['Armor Break', 'Rage IV'])
      fetch(filter: { main: 'true', sub: 'true' })
      expect(names).to eq(['Rage IV'])
    end

    it 'rejects a malformed job id' do
      fetch(filter: { job: 'berserker' })
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'sort and facets' do
    it 'sorts by order then name' do
      fetch(sort: '-order,name_en')
      expect(names).to eq(['Armor Break', 'Rage IV', 'Veil'])
    end

    it 'counts skills per job and colour' do
      body = fetch(filter: { color: '3' }, facets: 'job,color')
      expect(body['facets']['job']).to eq(sage.id => 1)
      expect(body['facets']['color']).to eq('2' => 2, '3' => 1)
    end
  end

  describe 'conditional GET' do
    it 'returns 200 after a job is renamed' do
      fetch
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      sage.update!(name_en: 'Sage II')
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
