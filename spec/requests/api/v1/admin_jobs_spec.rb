# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin jobs collection', type: :request do
  let(:path) { '/api/v1/admin/jobs' }
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

  # Fighter and Warrior share a granblue_id, as Class I and II jobs do in the game.
  let!(:fighter) do
    create(:job, name_en: 'Fighter', name_jp: 'ファイター', granblue_id: '900001', row: '1', order: 1,
                 proficiency1: 1, proficiency2: 4, accessory: false, accessory_type: 0,
                 master_level: false, ultimate_mastery: false, updated_at: Time.zone.parse('2026-01-01'))
  end
  let!(:warrior) do
    create(:job, name_en: 'Warrior', name_jp: 'ウォーリア', granblue_id: '900001', row: '2', order: 1,
                 proficiency1: 1, proficiency2: 4, accessory: false, accessory_type: 0,
                 master_level: false, ultimate_mastery: false, updated_at: Time.zone.parse('2026-02-01'))
  end
  let!(:paladin) do
    create(:job, name_en: 'Paladin', name_jp: 'パラディン', granblue_id: '900301', row: '4', order: 2,
                 proficiency1: 3, proficiency2: 1, accessory: true, accessory_type: 1,
                 master_level: true, ultimate_mastery: true, updated_at: Time.zone.parse('2026-03-01'))
  end

  before do
    # Drop the seeded jobs (rolled back after each example) so counts are exact.
    keep = [fighter, warrior, paladin].map(&:id)
    JobAccessory.delete_all
    JobSkill.delete_all
    Job.where.not(id: keep).delete_all
    create(:job_skill, job: paladin)
    create(:job_skill, job: paladin)
  end

  describe 'access' do
    it 'returns results for an editor with the default fields and sort' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(%w[Fighter Warrior Paladin])
      expect(body['results'].first.keys).to match_array(
        %w[id granblue_id name_en name_jp row order proficiency1 proficiency2 updated_at]
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

  describe 'q' do
    it 'matches names and granblue_id' do
      fetch(q: 'pala')
      expect(names).to eq(['Paladin'])
      fetch(q: '900001')
      expect(names).to eq(%w[Fighter Warrior])
    end
  end

  describe 'filters' do
    it 'filters by row, proficiency in either column, and accessory type' do
      fetch(filter: { row: '1,4' })
      expect(names).to eq(%w[Fighter Paladin])
      fetch(filter: { proficiency: '4' })
      expect(names).to eq(%w[Fighter Warrior])
      fetch(filter: { accessory_type: '1' })
      expect(names).to eq(['Paladin'])
    end

    it 'filters by booleans and the no-skills flag, both ways' do
      fetch(filter: { ultimate_mastery: 'true' })
      expect(names).to eq(['Paladin'])
      fetch(filter: { no_skills: 'false' })
      expect(names).to eq(['Paladin'])
    end

    it 'filters by when a job was last edited' do
      fetch(filter: { updated_at: { gte: '2026-02-01' } })
      expect(names).to eq(%w[Warrior Paladin])
    end

    it 'rejects an unknown filter' do
      fetch(filter: { element: '1' })
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'sort' do
    it 'sorts by any published column' do
      fetch(sort: '-name_en')
      expect(names).to eq(%w[Warrior Paladin Fighter])
      fetch(sort: '-order,name_en')
      expect(names).to eq(%w[Paladin Fighter Warrior])
    end
  end

  describe 'facets and fields' do
    it 'counts rows, proficiencies and accessory types' do
      body = fetch(filter: { row: '1' }, facets: 'row,proficiency,accessory_type')
      expect(body['facets']['row']).to eq('1' => 1, '2' => 1, '4' => 1)
      expect(body['facets']['proficiency']).to eq('1' => 1, '4' => 1)
      expect(body['facets']['accessory_type']).to eq('0' => 1)
    end

    it 'returns skill counts on request' do
      body = fetch(fields: 'name_en,skill_count,aux_weapon')
      expect(body['results'].map { |r| r['skill_count'] }).to eq([0, 0, 2])
      expect(body['results'].first.keys).to match_array(%w[id name_en skill_count aux_weapon])
    end
  end

  describe 'conditional GET' do
    it 'returns 304 for an unchanged collection and 200 after a skill is added' do
      fetch
      etag = response.headers['ETag']

      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      create(:job_skill, job: fighter)
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
