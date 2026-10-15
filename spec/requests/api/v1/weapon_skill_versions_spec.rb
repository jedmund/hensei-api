# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /api/v1/weapon_skill_versions/:id', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def patch_version(version, attrs, account: editor)
    patch "/api/v1/weapon_skill_versions/#{version.id}", headers: auth_headers(account),
                                                         params: { weapon_skill_version: attrs }.to_json
  end

  let(:version) do
    create(:weapon_skill_version, skill_modifier: 'Might', skill_series: 'normal', skill_size: 'medium')
  end

  it 'writes the override fields and stamps overrides_edited_at' do
    patch_version(version, { modifier_override: 'none', series_override: 'omega', size_override: 'big',
                             suppressed_boosts: ['hp'] })

    expect(response).to have_http_status(:ok)
    version.reload
    expect(version).to have_attributes(modifier_override: 'none', series_override: 'omega',
                                       size_override: 'big', suppressed_boosts: ['hp'])
    expect(version.overrides_edited_at).to be_present
    expect(version.resolved_modifier).to be_nil
    expect(response.parsed_body).to include('series_override' => 'omega', 'skill_series' => 'normal')
    expect(response.parsed_body).to include('skill_modifier' => 'Might', 'resolved_modifier' => nil,
                                            'resolved_series' => 'omega', 'resolved_size' => 'big')
  end

  it 'ignores the derived classification columns a reparse would overwrite' do
    patch_version(version, { skill_modifier: 'Enmity', skill_series: 'ex', skill_size: 'big' })

    expect(response).to have_http_status(:ok)
    expect(version.reload).to have_attributes(skill_modifier: 'Might', skill_series: 'normal', skill_size: 'medium',
                                              overrides_edited_at: nil)
  end

  it 'clears an override with a blank value' do
    version.update!(series_override: 'omega', overrides_edited_at: 1.day.ago)

    patch_version(version, { series_override: '' })

    expect(version.reload.series_override).to be_nil
    expect(version.resolved_series).to eq('normal')
    expect(response.parsed_body).to include('resolved_series' => 'normal', 'resolved_modifier' => 'Might',
                                            'resolved_size' => 'medium')
  end

  it 'does not stamp overrides_edited_at for a non-override edit' do
    patch_version(version, { main_hand_only: true })

    expect(version.reload.main_hand_only).to be(true)
    expect(version.overrides_edited_at).to be_nil
  end

  it 'rejects override values the derived columns would not accept' do
    patch_version(version, { series_override: 'bogus', modifier_override: 'Not A Family' })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(version.reload.series_override).to be_nil
  end

  it 'refuses non-editors' do
    patch_version(version, { series_override: 'omega' }, account: user)

    # ApiController#ensure_editor_role answers 401 for every editor-only endpoint.
    expect(response).to have_http_status(:unauthorized)
    expect(version.reload.series_override).to be_nil
  end

  describe 'surviving a reparse' do
    let(:wiki_raw) do
      <<~WIKI
        {{Weapon
        |id=1030101400
        |name=Sword Breaker
        |weapon=dagger
        |element=dark
        |rarity=sr
        |s1_name=Hatred's Might
        |s1_icon=ws_skill_atk_6_2.png
        |s1_desc=Medium boost to dark allies' ATK
        |evo_max=3
        }}
      WIKI
    end
    let(:weapon) do
      create(:weapon, granblue_id: '1030101400', name_en: 'Sword Breaker', wiki_en: 'Sword Breaker', wiki_raw: wiki_raw)
    end

    before do
      # The build reads stored sources only.
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).and_raise('no network in specs')
      WeaponSkills::SourceStore::Database.new.put('wiki_raw', weapon.wiki_en, wiki_raw, weapon_id: weapon.id,
                                                                                      page_kind: 'inline')
    end

    it 'keeps the override after EntityReparser rewrites the derived columns' do
      Granblue::EntityReparser.new(weapon).reparse
      parsed = WeaponSkillVersion.joins(:weapon_skill).find_by!(weapon_skills: { weapon_granblue_id: '1030101400' })
      expect(parsed.skill_series).to eq('normal')

      patch_version(parsed, { series_override: 'omega', size_override: 'big' })
      expect(response).to have_http_status(:ok)

      Granblue::EntityReparser.new(weapon.reload).reparse

      reparsed = WeaponSkillVersion.find(parsed.id)
      expect(reparsed).to have_attributes(skill_series: 'normal', series_override: 'omega', size_override: 'big')
      expect(reparsed.resolved_series).to eq('omega')
      expect(reparsed.resolved_size).to eq('big')
    end
  end
end
