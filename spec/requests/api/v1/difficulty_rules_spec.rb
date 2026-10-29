# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Difficulty rule drafts', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, scopes: 'public') }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }
  let(:attributes) do
    { name: 'Test rule', component: 'weapon', rule_type: 'weapon_uncap_at_least',
      params: { min_uncap_level: 5 }, weight: 1, active: true }
  end

  def create_draft
    post '/api/v1/difficulty_rules', params: { difficulty_rule: attributes }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    response.parsed_body.fetch('draft').fetch('id')
  end

  it 'edits a pending creation repeatedly without creating another draft, then commits the edited values' do
    id = create_draft
    2.times do |i|
      put "/api/v1/difficulty_rules/#{id}", params: { difficulty_rule: { weight: i + 2 } }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['draft']).to include('id' => id, 'operation' => 'create')
    end
    expect(DifficultyDraft.for_user(editor).count).to eq(1)
    expect(DifficultyDraft.find(id).attributes_payload).to include('name' => 'Test rule', 'weight' => 3)
    expect(DifficultyRule.where(name: 'Test rule')).not_to exist
    allow(Difficulty).to receive(:coverage_errors_for).and_return([])
    post '/api/v1/difficulty_drafts/commit', headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    rule = DifficultyRule.find_by!(name: 'Test rule')
    expect(rule.weight).to eq(3)
    put "/api/v1/difficulty_rules/#{rule.id}", params: { difficulty_rule: { weight: 4 } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(rule.reload.weight).to eq(3)
    delete "/api/v1/difficulty_rules/#{rule.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(rule.reload).to be_persisted
  end

  it 'cancels a creation rather than staging a deletion' do
    id = create_draft
    delete "/api/v1/difficulty_rules/#{id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(DifficultyDraft.for_user(editor)).to be_empty
    expect(DifficultyRule.where(name: 'Test rule')).not_to exist
  end

  it 'leaves the previous draft intact after an invalid edit' do
    id = create_draft
    put "/api/v1/difficulty_rules/#{id}", params: { difficulty_rule: { params: {} } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(DifficultyDraft.find(id).attributes_payload['params']).to eq('min_uncap_level' => 5)
  end

  it 'rejects an invalid creation' do
    post '/api/v1/difficulty_rules', params: { difficulty_rule: attributes.merge(params: {}) }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(DifficultyDraft.for_user(editor)).to be_empty
  end

  it 'does not expose another editor’s creation or a different target type' do
    foreign = DifficultyDraft.create!(user: create(:user, role: 7), target_type: 'DifficultyRule', operation: 'create',
                                      attributes_payload: attributes)
    tier = DifficultyDraft.create!(user: editor, target_type: 'Difficulty', operation: 'create', attributes_payload: {})
    [foreign, tier].each do |draft|
      put "/api/v1/difficulty_rules/#{draft.id}", params: { difficulty_rule: { name: 'Changed' } }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      delete "/api/v1/difficulty_rules/#{draft.id}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(draft.reload).to be_persisted
    end
  end

  it 'rejects non-editors' do
    editor.update!(role: 0)
    post '/api/v1/difficulty_rules', params: { difficulty_rule: attributes }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns editor metadata for every registered type' do
    get '/api/v1/difficulty_rules/types', headers: headers
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['definitions'].pluck('rule_type')).to match_array(body['types'])
    body['definitions'].each do |definition|
      expect(definition['component']).to eq(PartyDifficulty::Rules.component_for(definition['rule_type']))
      expect(definition['parameters'].pluck('key')).to include(*definition['params'].keys)
    end
  end
end
