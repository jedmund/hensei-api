# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Weapon skill admin API', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }
  let(:editor_headers) { auth_headers(editor) }
  let(:user_headers) { auth_headers(user) }

  def auth_headers(u)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: u.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  let!(:datum) do
    WeaponSkillDatum.create!(modifier: 'Spectest', boost_type: 'atk', series: 'normal',
                             size: 'big', formula_type: 'flat', sl15: 18.0)
  end
  let!(:effect) do
    WeaponSkillEffect.create!(modifier: 'Spectest', boost_type: 'dmg_cap', scaling_kind: 'static',
                              value: 10.0, stacking: 'additive')
  end

  describe 'GET /api/v1/weapon_skill_families' do
    it 'lists families aggregated from data and effects' do
      get '/api/v1/weapon_skill_families', params: { q: 'spectest' }
      expect(response).to have_http_status(:ok)
      fam = response.parsed_body['weapon_skill_families'].sole
      expect(fam['modifier']).to eq('Spectest')
      expect(fam['boost_types']).to contain_exactly('atk', 'dmg_cap')
      expect(fam['counts']).to include('data_rows' => 1, 'effect_rows' => 1)
    end

    it 'filters by boost_type' do
      get '/api/v1/weapon_skill_families', params: { boost_type: 'dmg_cap' }
      mods = response.parsed_body['weapon_skill_families'].map { |f| f['modifier'] }
      expect(mods).to include('Spectest')
      get '/api/v1/weapon_skill_families', params: { boost_type: 'nope' }
      expect(response.parsed_body['weapon_skill_families']).to be_empty
    end
  end

  describe 'GET /api/v1/weapon_skill_families/:modifier' do
    it 'returns the aggregate' do
      get "/api/v1/weapon_skill_families/#{ERB::Util.url_encode('Spectest')}"
      expect(response).to have_http_status(:ok)
      fam = response.parsed_body['weapon_skill_family']
      expect(fam['data'].sole['sl15']).to eq(18.0)
      expect(fam['effects'].sole['source']).to eq('canonical')
    end

    it '404s on unknown modifiers' do
      get '/api/v1/weapon_skill_families/Nonexistent'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'weapon_skill_data CRUD' do
    it 'creates rows with a manual stamp' do
      post '/api/v1/weapon_skill_data', headers: editor_headers,
                                        params: { weapon_skill_datum: { modifier: 'Spectest', boost_type: 'hp',
                                                                        series: 'normal', size: 'small',
                                                                        formula_type: 'flat', sl15: 9.0 } }.to_json
      expect(response).to have_http_status(:created)
      expect(WeaponSkillDatum.find(response.parsed_body['id']).manually_edited_at).to be_present
    end

    it 'updates values' do
      patch "/api/v1/weapon_skill_data/#{datum.id}", headers: editor_headers,
                                                     params: { weapon_skill_datum: { sl15: 20.0 } }.to_json
      expect(response).to have_http_status(:ok)
      expect(datum.reload.sl15).to eq(20.0)
      expect(datum.manually_edited_at).to be_present
    end

    it 'rejects non-editors' do
      patch "/api/v1/weapon_skill_data/#{datum.id}", headers: user_headers,
                                                     params: { weapon_skill_datum: { sl15: 1.0 } }.to_json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'guards deletes behind a blast-radius confirmation' do
      might = WeaponSkillDatum.create!(modifier: 'Might', boost_type: 'atk', series: 'normal',
                                       size: 'big', formula_type: 'flat', sl15: 18.0)
      weapon = create(:weapon)
      skill = create(:skill)
      ws = WeaponSkill.create!(weapon_granblue_id: weapon.granblue_id, position: 0)
      WeaponSkillVersion.create!(weapon_skill: ws, skill: skill, ordinal: 0, skill_modifier: 'Might')

      delete "/api/v1/weapon_skill_data/#{might.id}", headers: editor_headers
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['affected_weapons']).to eq(1)
      expect(WeaponSkillDatum.exists?(might.id)).to be(true)

      delete "/api/v1/weapon_skill_data/#{might.id}?force=true", headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(WeaponSkillDatum.exists?(might.id)).to be(false)
    end
  end

  describe 'weapon_skill_effects CRUD' do
    it 'updates values and conditions' do
      patch "/api/v1/weapon_skill_effects/#{effect.id}", headers: editor_headers,
                                                         params: { weapon_skill_effect: {
                                                           value: 5.0, condition: { type: 'arcarum', eq: true }
                                                         } }.to_json
      expect(response).to have_http_status(:ok)
      effect.reload
      expect(effect.value).to eq(5.0)
      expect(effect.condition).to eq({ 'type' => 'arcarum', 'eq' => true })
      expect(effect.manually_edited_at).to be_present
    end

    it 'deletes without confirmation when nothing references the family' do
      delete "/api/v1/weapon_skill_effects/#{effect.id}", headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(WeaponSkillEffect.exists?(effect.id)).to be(false)
    end
  end

  describe 'version classification + skill labels + keys' do
    let(:weapon) { create(:weapon) }
    let(:skill) { create(:skill, name_en: 'Old Name') }
    let(:version) do
      ws = WeaponSkill.create!(weapon_granblue_id: weapon.granblue_id, position: 0)
      WeaponSkillVersion.create!(weapon_skill: ws, skill: skill, ordinal: 0, skill_series: 'normal')
    end

    it 'updates classification on the version' do
      patch "/api/v1/weapon_skill_versions/#{version.id}", headers: editor_headers,
                                                           params: { weapon_skill_version: {
                                                             skill_series: 'ex', skill_size: 'big', main_hand_only: true
                                                           } }.to_json
      expect(response).to have_http_status(:ok)
      expect(version.reload.skill_series).to eq('ex')
      expect(version.main_hand_only).to be(true)
    end

    it 'updates labels on the shared skill with a share count' do
      version
      patch "/api/v1/skills/#{skill.id}", headers: editor_headers,
                                          params: { skill: { name_en: 'New Name' } }.to_json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['shared_by_count']).to eq(1)
      expect(skill.reload.name_en).to eq('New Name')
    end

    it 'updates weapon key names' do
      key = WeaponKey.create!(name_en: 'Old Key', slug: 'spec-key', slot: 0)
      patch "/api/v1/weapon_keys/#{key.id}", headers: editor_headers,
                                             params: { weapon_key: { name_en: 'New Key' } }.to_json
      expect(response).to have_http_status(:ok)
      expect(key.reload.name_en).to eq('New Key')
    end
  end
end
