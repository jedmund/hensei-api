# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entity reparse endpoints', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }
  let(:editor_headers) { auth_headers(editor) }
  let(:user_headers) { auth_headers(user) }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
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
    let(:weapon) { create(:weapon, element: 3, wiki_en: 'Spec Blade', wiki_raw: wiki_raw) }

    def store_source
      WeaponSkills::SourceStore::Database.new.put('wiki_raw', weapon.wiki_en, wiki_raw, weapon_id: weapon.id,
                                                                                      page_kind: 'inline')
    end

    it 'rebuilds skills from the stored source with the weapon-skill build' do
      store_source
      post "/api/v1/weapons/#{weapon.id}/reparse", headers: editor_headers

      expect(response).to have_http_status(:ok)
      versions = WeaponSkillVersion.joins(:weapon_skill)
                                   .where(weapon_skills: { weapon_granblue_id: weapon.granblue_id })
      expect(versions.count).to eq(1)
      expect(versions.first).to have_attributes(skill_series: 'normal', skill_size: 'big',
                                                description_en: "Big boost to water allies' ATK")
      expect(weapon.reload.weapon_skill_build_fingerprint).to be_present
    end

    it 'keeps generated skills when the source was never stored' do
      store_source
      post "/api/v1/weapons/#{weapon.id}/reparse", headers: editor_headers
      WeaponSource.where(weapon_id: weapon.id).delete_all

      post "/api/v1/weapons/#{weapon.id}/reparse", headers: editor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/stored wiki source/i)
      expect(WeaponSkill.where(weapon_granblue_id: weapon.granblue_id).count).to eq(1)
    end

    it 'fetches the sources and then builds on fetch_wiki' do
      allow(Granblue::WikiFetcher).to receive(:new).and_return(instance_double(Granblue::WikiFetcher))
      allow(Granblue::WikiFetcher.new).to receive(:fetch_and_store) { store_source }

      post "/api/v1/weapons/#{weapon.id}/fetch_wiki", headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(WeaponSkill.where(weapon_granblue_id: weapon.granblue_id).count).to eq(1)
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

    context 'with stored wikitext' do
      include BuildLockHelpers

      let(:fixtures) { Rails.root.join('spec/fixtures/character_skills') }
      let(:character) do
        create(:character, granblue_id: '3040252000', name_en: 'Vikala',
                           wiki_raw: fixtures.join('character-vikala-wikidata.txt').read,
                           game_raw_en: JSON.parse(fixtures.join('character-vikala-gamedata.json').read))
      end

      def version_ids
        CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: character.id })
                             .order(:id).pluck(:id, :name_en, :game_icon)
      end

      it 'builds the skills, then keeps their ids on a second reparse' do
        post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
        expect(response).to have_http_status(:ok)
        first = version_ids
        expect(first).not_to be_empty
        expect(character.reload.character_skill_build_fingerprint).to be_present

        post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
        expect(response).to have_http_status(:ok)
        expect(version_ids).to eq(first)
      end

      it 'raises Busy from EntityReparser while another build of the character runs' do
        stub_const('Granblue::EntityReparser::LOCK_WAIT', 0.2)
        held_elsewhere(:character, character.id) do
          expect { Granblue::EntityReparser.new(character).reparse }
            .to raise_error(CharacterSkills::BuildLock::Busy, /Try again in a minute/)
        end
        expect(CharacterSkill.where(character_id: character.id)).to be_empty
        expect(Granblue::EntityReparser.new(character).reparse[:built]).to eq(1)
      end

      it 'refuses a reparse whose build makes no skills, and keeps the existing ones' do
        post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
        ids = version_ids
        put_source(character, :wiki_raw, '#REDIRECT [[Somewhere]]')

        post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to include('the build made no skills; kept its existing skills')
        expect(version_ids).to eq(ids)
      end

      it "builds only this row, not its style shift's" do
        style = create(:character, granblue_id: character.granblue_id, style_swap: true, wiki_raw: character.wiki_raw)
        post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
        expect(CharacterSkill.where(character_id: style.id)).to be_empty
      end

      context 'when the character has no game data' do
        before do
          # Wiki icon stems that differ from the game's class_names, so only the snapshot
          # can bring the game's icons back.
          put_source(character, :wiki_raw, character.wiki_raw.gsub(/^\|(a\d_icon)=.*$/, '|\1= Ability_m_9999_1.png'))
        end

        it 'a reparse of a character without game data keeps its icons (via the snapshot)' do
          post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
          with_game_data = version_ids
          expect(with_game_data.map(&:last)).to include('1065_1', '1947_3')
          expect(with_game_data.map(&:last)).not_to include('9999_1')

          CharacterSkills::IconSnapshot.export
          put_source(character, :game_raw_en, nil)

          post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
          expect(response).to have_http_status(:ok)
          expect(version_ids).to eq(with_game_data)
        end

        it 'falls back to the wiki stems without a snapshot entry' do
          post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
          put_source(character, :game_raw_en, nil)

          post "/api/v1/characters/#{character.id}/reparse", headers: editor_headers
          expect(version_ids.map(&:last)).to include('9999_1')
        end
      end
    end
  end
end
