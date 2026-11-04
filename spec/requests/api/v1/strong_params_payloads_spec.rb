# frozen_string_literal: true

require 'rails_helper'

# Pins what each strong-params endpoint answers when its root key holds
# something other than an object (`{ "weapon": "oops" }`).
RSpec.describe 'Strong params payload shapes', type: :request do
  let(:admin) { create(:user, role: 9) }
  let(:crew) { create(:crew) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: admin.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end
  let(:party) { create(:party, user: admin) }
  let(:participation) { create(:crew_gw_participation, crew: crew) }

  before { create(:crew_membership, :captain, crew: crew, user: admin) }

  endpoints = [
    [:post, -> { '/api/v1/weapons' }, :weapon],
    [:post, -> { '/api/v1/characters' }, :character],
    [:post, -> { '/api/v1/summons' }, :summon],
    [:post, -> { '/api/v1/raid_groups' }, :raid_group],
    [:post, -> { '/api/v1/raids' }, :raid],
    [:post, -> { '/api/v1/weapon_series' }, :weapon_series],
    [:post, -> { "/api/v1/weapon_series/#{create(:weapon_series).id}/weapon_series_variants" }, :weapon_series_variant],
    [:post, -> { '/api/v1/character_series' }, :character_series],
    [:post, -> { '/api/v1/summon_series' }, :summon_series],
    [:post, -> { '/api/v1/awakenings' }, :awakening],
    [:post, -> { '/api/v1/weapon_skill_data' }, :weapon_skill_datum],
    [:patch, -> { "/api/v1/weapon_skill_versions/#{create(:weapon_skill_version).id}" }, :weapon_skill_version],
    [:patch, -> { "/api/v1/skills/#{create(:skill).id}" }, :skill],
    [:patch, -> { "/api/v1/weapon_keys/#{create(:weapon_key).id}" }, :weapon_key],
    [:post, -> { '/api/v1/stickers' }, :sticker],
    [:post, -> { '/api/v1/events' }, :event],
    [:post, -> { '/api/v1/gw_events' }, :gw_event],
    [:post, -> { '/api/v1/difficulties' }, :difficulty],
    [:patch, lambda {
      "/api/v1/difficulty_components/#{DifficultyComponent.create!(name: 'weapon', weight: 1, enabled: true).id}"
    }, :difficulty_component],
    [:post, -> { '/api/v1/difficulty_drafts' }, :draft],
    [:post, -> { '/api/v1/collection/job_accessories' }, :collection_job_accessory],
    [:post, -> { '/api/v1/collection/artifacts' }, :collection_artifact],
    [:post, -> { '/api/v1/support_summons' }, :support_summon],
    [:post, -> { '/api/v1/playlists' }, :playlist],
    [:post, -> { '/api/v1/favorites' }, :favorite],
    [:put, -> { "/api/v1/parties/#{party.shortcode}/jobs" }, :party],
    [:patch, -> { '/api/v1/crew' }, :crew],
    [:patch, lambda {
      "/api/v1/crews/#{crew.id}/memberships/#{create(:crew_membership, crew: crew).id}"
    }, :membership],
    [:post, -> { "/api/v1/crews/#{crew.id}/phantom_players" }, :phantom_player],
    [:patch, -> { "/api/v1/crew/gw_participations/#{participation.id}" }, :crew_gw_participation],
    [:post, -> { "/api/v1/crew/gw_participations/#{participation.id}/crew_scores" }, :crew_score],
    [:post, -> { "/api/v1/crew/gw_participations/#{participation.id}/individual_scores" }, :individual_score]
  ]

  endpoints.each do |verb, path, root|
    it "#{verb.upcase} with a non-object #{root} answers 422 naming the param" do
      public_send(verb, instance_exec(&path), params: { root => 'oops' }, headers: headers, as: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('errors', 'param')).to eq(root.to_s)
    end
  end

  # set_party digs the party id out of the payload before the params are read
  it 'POST with a non-object substitution still answers 500' do
    post '/api/v1/substitutions', params: { substitution: 'oops' }, headers: headers, as: :json

    expect(response).to have_http_status(:internal_server_error)
  end

  describe 'a payload whose fields are all unpermitted' do
    it 'saves nothing and answers 422' do
      key = create(:weapon_key, name_en: 'Before')
      patch "/api/v1/weapon_keys/#{key.id}", params: { weapon_key: { unknown: 'x' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(key.reload.name_en).to eq('Before')
    end

    it 'leaves the user unchanged and answers 422' do
      put '/api/v1/users/me', params: { user: { unknown: 'x' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PUT /api/v1/users/me with password_prompt_dismissed' do
    it 'dismisses the prompt from a payload holding only the flag' do
      put '/api/v1/users/me', params: { user: { password_prompt_dismissed: true } }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(admin.reload.password_prompt_dismissed_at).to be_present
    end

    it 'applies the flag alongside a profile field' do
      put '/api/v1/users/me', params: { user: { password_prompt_dismissed: true, display_name: 'Renamed' } },
                              headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(admin.reload).to have_attributes(display_name: 'Renamed', password_prompt_dismissed_at: be_present)
    end
  end

  describe 'PUT /api/v1/difficulty_rules/:id with only params' do
    let(:rule_id) do
      post '/api/v1/difficulty_rules', params: {
        difficulty_rule: { name: 'Spec rule', component: 'weapon', rule_type: 'weapon_uncap_at_least', weight: 1,
                           active: true, params: { min_uncap_level: 5 } }
      }, headers: headers, as: :json
      response.parsed_body.dig('draft', 'id')
    end

    it 'refuses a non-object params with 422' do
      put "/api/v1/difficulty_rules/#{rule_id}", params: { difficulty_rule: { params: 'x' } },
                                                 headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'stages nested params' do
      put "/api/v1/difficulty_rules/#{rule_id}", params: { difficulty_rule: { params: { min_uncap_level: 4 } } },
                                                 headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(DifficultyDraft.find(rule_id).attributes_payload['params']).to eq('min_uncap_level' => 4)
    end
  end

  # condition is NOT NULL, so a payload holding only a null condition has nothing to save
  describe 'PATCH /api/v1/weapon_skill_effects/:id with only a null condition' do
    it 'keeps the condition and answers 422' do
      effect = WeaponSkillEffect.create!(modifier: 'Spectest', boost_type: 'dmg_cap', scaling_kind: 'static',
                                         value: 10.0, stacking: 'additive', condition: { 'type' => 'arcarum' })
      patch "/api/v1/weapon_skill_effects/#{effect.id}", params: { weapon_skill_effect: { condition: nil } },
                                                         headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(effect.reload.condition).to eq('type' => 'arcarum')
    end
  end

  describe 'required body ids' do
    it 'answers 422 when assigning a phantom without a user_id' do
      phantom = create(:phantom_player, crew: crew)
      post "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}/assign", params: {}, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'answers 422 when importing GW scores without an event_number' do
      post '/api/v1/crew/import_gw_scores', params: { round: 1, members: [] }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
