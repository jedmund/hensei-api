# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entity reparse endpoints', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }
  let(:editor_headers) { auth_headers(editor) }
  let(:user_headers) { auth_headers(user) }

  def auth_headers(u)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: u.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/summons/:id/reparse' do
    let(:wiki_raw) do
      <<~WIKI
        {{Summon
        |aura1=50% boost to Water Elemental ATK.
        |aura2=80% boost to Water Elemental ATK.
        |subaura1=10% boost to water allies' ATK.
        }}
      WIKI
    end
    let(:summon) { create(:summon, element: 3, wiki_raw: wiki_raw) }

    it 'parses auras into structured rows and prunes stale ones' do
      create(:summon_aura, summon_granblue_id: summon.granblue_id, slot: 'main',
                           uncap_level: 3, transcendence_stage: 0, target: 'other', value: 1)
      stale = create(:summon_aura, summon_granblue_id: summon.granblue_id, slot: 'sub',
                     uncap_level: 5, transcendence_stage: 3, target: 'other', value: 99)

      post "/api/v1/summons/#{summon.id}/reparse", headers: editor_headers

      expect(response).to have_http_status(:ok)
      auras = SummonAura.where(summon_granblue_id: summon.granblue_id)
      expect(auras.where(slot: 'main').count).to eq(2)
      expect(auras.where(slot: 'sub').count).to eq(1)
      expect(SummonAura.exists?(stale.id)).to be(false)
      expect(auras.find_by(slot: 'main', uncap_level: 0).value).to eq(50)
    end

    it 'rejects non-editors' do
      post "/api/v1/summons/#{summon.id}/reparse", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'fails cleanly without stored wikitext' do
      summon.update!(wiki_raw: nil)
      post "/api/v1/summons/#{summon.id}/reparse", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/wikitext/i)
    end
  end

  describe 'POST /api/v1/weapons/:id/reparse' do
    let(:wiki_raw) do
      <<~WIKI
        {{Weapon
        |name=Spec Blade
        |s1_name=Water's Might
        |s1_icon=ws_skill_atk_2_2.png
        |s1_desc=Big boost to water allies' ATK
        |s1_lvl=1
        }}
      WIKI
    end
    let(:weapon) { create(:weapon, element: 3, wiki_raw: wiki_raw) }

    it 'rebuilds skills and reruns description extraction' do
      post "/api/v1/weapons/#{weapon.id}/reparse", headers: editor_headers

      expect(response).to have_http_status(:ok)
      versions = WeaponSkillVersion.joins(:weapon_skill)
                                   .where(weapon_skills: { weapon_granblue_id: weapon.granblue_id })
      expect(versions.count).to be >= 1
      expect(versions.first.skill_series).to be_present
    end

    it 'rejects non-editors' do
      post "/api/v1/weapons/#{weapon.id}/reparse", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/characters/:id/reparse' do
    let(:character) { create(:character, wiki_raw: nil) }

    it 'fails cleanly without stored wikitext' do
      post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
