# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ImportController Evoking Solomonis runs', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  let(:fixture_dir) { Rails.root.join('spec/fixtures/solomonis') }
  let(:report) { JSON.parse(File.read(fixture_dir.join('report-detail.json')))['report'] }
  let(:status_list) { JSON.parse(File.read(fixture_dir.join('report-spacebook-en.json')))['status_list'] }
  let(:seed_effects) do
    JSON.parse(Rails.root.join('db/seed/solomonis/guide_effects.json').read)['guide_effects']
  end

  let(:zone) { create(:raid, :solomonis_zone) }
  # The canonical test data may already hold some of these characters.
  let!(:nier) do
    character = Character.find_by(granblue_id: '3040169000') || create(:character, granblue_id: '3040169000')
    character.update!(solomonis_zone: zone, element: 5, transcendence: true, max_transcendence_stage: 5)
    character
  end
  let!(:allies) do
    %w[3040265000 3040554000 3040639000 3040610000].map do |id|
      Character.find_by(granblue_id: id) || create(:character, granblue_id: id)
    end
  end
  let!(:job) { create(:job, granblue_id: '130501') }

  let(:body) do
    {
      'kind' => 'solomonis_run',
      'playlist_ids' => [],
      'solomonis' => { 'report_id' => 381099, 'report' => report, 'status_list' => status_list },
      'update_existing' => false
    }
  end

  def auth_headers_for(owner)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: owner.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  # The catalogue as seeded, for the given status IDs.
  def seed_catalogue(ids)
    seed_effects.select { |e| ids.include?(e['granblue_id']) }.each do |e|
      SolomonisGuideEffect.create!(e.except('character_granblue_id').merge('character_id' => nil))
    end
  end

  def import(payload = body, as: headers)
    post '/api/v1/import', params: payload.to_json, headers: as
  end

  def imported_party
    Party.find(response.parsed_body['party_id'])
  end

  def effect(granblue_id)
    SolomonisGuideEffect.find_by!(granblue_id: granblue_id)
  end

  around { |example| travel_to(Time.zone.parse('2026-10-12T12:00:00+09:00')) { example.run } }

  before { seed_catalogue(status_list.pluck('status_id')) }

  describe 'POST /api/v1/import with kind solomonis_run' do
    it 'imports a run from the report and its guidebook' do
      expect { import }.to change(Party, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.keys).to contain_exactly('party_id', 'shortcode', 'warnings')
      expect(response.parsed_body['warnings']).to eq([])

      party = imported_party
      expect(party.user).to eq(user)
      expect(party.shortcode).to eq(response.parsed_body['shortcode'])
      expect(party.name).to eq('Nier Party')
      expect(party.raid).to eq(zone)
      expect(party.element).to eq(5)
      expect(party.turn_count).to eq(109)
      expect(party.job).to eq(job)
      expect(party.characters.map { |gc| gc.character.granblue_id })
        .to match_array(%w[3040169000 3040265000 3040554000 3040639000 3040610000])
      expect(party.characters.find_by(character: nier).uncap_level).to eq(6)

      expedition = party.solomonis_expedition
      expect(expedition).to have_attributes(
        kind: 'run', route_evoker: nier, pledge_level: 0, outcome: 'cleared',
        bosses_defeated: 2, game_report_id: 381099, midboss: nil
      )
      expect(expedition.ended_at).to eq(Time.zone.parse('2026-10-11T16:38:00+09:00'))
      expect(expedition.stats).to eq(
        'battle' => 14, 'strong' => 0, 'terrifying' => 0, 'ruler' => 0, 'boss' => 2, 'event' => 20,
        'healing' => 6, 'chest' => 5, 'teleporter' => 0, 'special' => 1, 'shop_purchases' => 18,
        'points_earned' => 2924
      )
    end

    it 'stores the guidebook with counts and run values' do
      import

      rows = imported_party.expedition_guide_effects.includes(:solomonis_guide_effect)
                           .index_by { |row| row.solomonis_guide_effect.granblue_id }
      expect(rows.keys).to match_array(status_list.pluck('status_id'))
      expect(rows.values.sum(&:count)).to eq(71)
      expect(rows[7].count).to eq(6)
      expect(rows.transform_values(&:display_value).compact).to eq(85 => '80%', 45 => '+3', 53 => '2', 55 => '1')
      expect(rows.values).to all(have_attributes(inherited: false, acquired_order: nil))
    end

    it 'leaves weapons, summons and blessings empty without a current setup' do
      import

      party = imported_party
      expect(party.weapons).to be_empty
      expect(party.summons).to be_empty
      expect(party.party_blessings).to be_empty
    end

    it 'takes the name, visibility and playlists from the request' do
      playlist = create(:playlist, user: user)
      import(body.merge('name' => 'My run', 'visibility' => 3, 'playlist_ids' => [playlist.id]))

      party = imported_party
      expect(party).to have_attributes(name: 'My run', visibility: 3)
      expect(party.playlists).to contain_exactly(playlist)
    end

    context 'when the report was already imported' do
      before { import }

      let!(:first_party) { imported_party }

      it 'returns 409 with the existing run' do
        expect { import }.not_to change(Party, :count)

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body).to eq(
          'error' => 'duplicate_report', 'party_id' => first_party.id, 'shortcode' => first_party.shortcode
        )
      end

      it 'updates the run in place with update_existing, keeping what the user added' do
        first_party.update!(name: 'Renamed')
        first_party.solomonis_expedition.update!(midboss: 'banes_gate')
        first_party.expedition_guide_effects.find_by(solomonis_guide_effect: effect(7)).update!(note: 'great')
        dropped = first_party.characters.find_by(character: allies.first)
        replacement = create(:character, granblue_id: '3040999000')

        new_report = report.merge('npc1_image_id' => '3040999000_03', 'total_turn' => '120')
        new_list = status_list.map { |e| e['status_id'] == 7 ? e.merge('num' => 7) : e }
                              .reject { |e| e['status_id'] == 1 }
        payload = body.merge('update_existing' => true,
                             'solomonis' => body['solomonis'].merge('report' => new_report, 'status_list' => new_list))

        expect { import(payload) }.not_to change(Party, :count)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['party_id']).to eq(first_party.id)
        expect(response.parsed_body['shortcode']).to eq(first_party.shortcode)
        expect(response.parsed_body['warnings'])
          .to eq(['spacebook_status_count is 71 but the guidebook holds 52 stacks'])

        party = first_party.reload
        expect(party.name).to eq('Renamed')
        expect(party.turn_count).to eq(120)
        expect(party.solomonis_expedition.midboss).to eq('banes_gate')
        expect(GridCharacter.exists?(dropped.id)).to be(false)
        expect(party.characters.map(&:character)).to include(replacement)
        expect(party.characters.count).to eq(5)

        row = party.expedition_guide_effects.find_by(solomonis_guide_effect: effect(7))
        expect(row).to have_attributes(count: 7, note: 'great')
        expect(party.expedition_guide_effects.exists?(solomonis_guide_effect: effect(1))).to be(false)
      end
    end

    context "when someone else imported the same report" do
      let(:other_user) { create(:user) }

      before { import(body, as: auth_headers_for(other_user)) }

      let!(:their_party) { imported_party }

      it 'creates a separate run and leaves theirs alone, even with update_existing' do
        expect { import(body.merge('update_existing' => true)) }.to change(Party, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['party_id']).not_to eq(their_party.id)
        expect(imported_party.user).to eq(user)
        expect(their_party.reload.user).to eq(other_user)
        expect(their_party.solomonis_expedition.reload.user_id).to eq(other_user.id)
      end
    end

    context 'with an unknown status_id' do
      let(:new_entry) do
        {
          'name' => 'Bonus DMG to sabre- and gun-specialty allies @@(30%)', 'target_type' => 2,
          'target_param' => '1_6', 'display_ailment_id' => nil, 'status_id' => 109, 'icon_category' => 1,
          'icon_type' => 401, 'rarity' => 3, 'is_duplication_possible' => 0, 'deck_condition' => 0, 'num' => 1
        }
      end

      it 'adds the effect to the catalogue for review and imports it' do
        payload = body.deep_merge('solomonis' => { 'status_list' => status_list + [new_entry] })
        payload['solomonis']['report'] = report.merge('spacebook_status_count' => 72)

        expect { import(payload) }.to change(SolomonisGuideEffect, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['warnings']).to eq([])
        added = effect(109)
        expect(added).to have_attributes(
          rarity: 'unique', stackable: false, needs_review: true, name_jp: nil,
          name_en: 'Bonus DMG to sabre- and gun-specialty allies (30%)',
          icon_category: 1, icon_type: 401, target_type: 'proficiency', target_values: [1, 9]
        )
        expect(imported_party.expedition_guide_effects.find_by(solomonis_guide_effect: added).count).to eq(1)
      end

      it 'resolves a character effect to its route Evoker' do
        fraux = create(:character, :solomonis_evoker, granblue_id: '3040161000', character_id: [3100], solomonis_zone: zone)
        entry = new_entry.merge('target_type' => 3, 'target_param' => '3100', 'deck_condition' => 3100)
        payload = body.deep_merge('solomonis' => { 'status_list' => status_list + [entry] })
        import(payload)

        expect(effect(109)).to have_attributes(target_type: 'character', target_values: [3100], character_id: fraux.id)
      end

      it 'skips an entry with an unknown rarity, with a warning' do
        payload = body.deep_merge('solomonis' => { 'status_list' => status_list + [new_entry.merge('rarity' => 7)] })

        expect { import(payload) }.not_to change(SolomonisGuideEffect, :count)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['warnings']).to include('New guidebook effect 109 has an unknown rarity; skipped')
      end
    end

    context 'with Japanese text' do
      let(:japanese_entry) do
        {
          'name' => '全体の与ダメージ上昇@@(80% / 最大: 100%)', 'target_type' => nil, 'target_param' => '',
          'display_ailment_id' => nil, 'status_id' => 110, 'icon_category' => 1, 'icon_type' => 310,
          'rarity' => 3, 'is_duplication_possible' => 1, 'deck_condition' => 0, 'num' => 1
        }
      end

      it 'stores a new effect under name_jp' do
        payload = body.deep_merge('solomonis' => { 'status_list' => [japanese_entry] })
        import(payload)

        expect(response).to have_http_status(:created)
        expect(effect(110)).to have_attributes(name_jp: '全体の与ダメージ上昇(80% / 最大: 100%)', name_en: nil,
                                               needs_review: true)
      end

      it 'fills the empty language of a known effect and never overwrites it' do
        known = status_list.find { |e| e['status_id'] == 7 }
        jp = known.merge('name' => '与ダメージ上限+10%')
        import(body.deep_merge('solomonis' => { 'status_list' => [jp] }))

        expect(effect(7)).to have_attributes(name_en: 'DMG cap +10%', name_jp: '与ダメージ上限+10%', needs_review: true)

        other = create(:user)
        later = jp.merge('name' => '与ダメージ上限アップ')
        import(body.deep_merge('solomonis' => { 'status_list' => [later] }), as: auth_headers_for(other))

        expect(response).to have_http_status(:created)
        expect(effect(7).name_jp).to eq('与ダメージ上限+10%')
      end
    end

    it 'warns when the guidebook does not match spacebook_status_count' do
      captured_ids = [7, 74]
      import(body.deep_merge('solomonis' => { 'status_list' => status_list.select { |e| e['status_id'].in?(captured_ids) } }))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['warnings']).to eq(['spacebook_status_count is 71 but the guidebook holds 7 stacks'])
    end

    it 'skips malformed guidebook entries with a warning' do
      list = [{ 'status_id' => 'x', 'num' => 1 }, status_list.first.merge('num' => -1), 'nope'] + status_list
      import(body.deep_merge('solomonis' => { 'status_list' => list }))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['warnings']).to eq(
        [
          'Guidebook entry 1 has no valid status_id; skipped',
          'Guidebook entry 2 (status 74) has no valid num; skipped',
          "Guidebook entry 3 isn't an object; skipped"
        ]
      )
    end

    it 'keeps the game values that break Hensei rules as warnings' do
      odd = report.merge('boss_count' => '1', 'difficulty' => 9)
      import(body.deep_merge('solomonis' => { 'report' => odd }))

      expect(response).to have_http_status(:created)
      expect(imported_party.solomonis_expedition).to have_attributes(outcome: 'cleared', bosses_defeated: nil,
                                                                     pledge_level: 0)
      expect(response.parsed_body['warnings']).to contain_exactly(
        "difficulty 9 isn't a pledge level (0–5); saved as 0",
        'a cleared run reports boss_count 1; bosses defeated left empty'
      )
    end

    it 'rejects a report whose Evoker cannot lead a route' do
      import(body.deep_merge('solomonis' => { 'report' => report.merge('thumbnail_image' => '3040265000_02') }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('unknown_route_evoker')
      expect(Party.count).to eq(0)
    end

    it 'rejects a missing report_id' do
      import(body.deep_merge('solomonis' => { 'report_id' => nil }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('invalid_data')
    end

    it 'rejects more than 300 guidebook entries' do
      list = Array.new(301) { |i| status_list.first.merge('status_id' => 1000 + i) }
      import(body.deep_merge('solomonis' => { 'status_list' => list }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('too_many_guide_effects')
      expect(SolomonisGuideEffect.where(granblue_id: 1000..).count).to eq(0)
    end

    it 'rejects a payload that is too large' do
      payload = body.deep_merge('solomonis' => { 'report' => report.merge('padding' => 'x' * 1.megabyte) })

      expect { import(payload) }.not_to change(Party, :count)
      expect(response).to have_http_status(:payload_too_large)
    end

    it 'requires a signed-in user' do
      expect { import(body, as: { 'Content-Type' => 'application/json' }) }.not_to change(Party, :count)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'warns about a current setup that is not a party deck' do
      import(body.deep_merge('solomonis' => { 'current_setup' => { 'foo' => 1 } }))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['warnings'])
        .to eq(["current_setup isn't a party deck; weapons and summons weren't imported"])
    end

    it 'imports weapons and summons from a current setup, without a support summon' do
      deck = JSON.parse(Rails.root.join('spec/fixtures/deck_sample.json').read)
      import(body.deep_merge('solomonis' => { 'current_setup' => deck }))

      expect(response).to have_http_status(:created)
      expect(imported_party.summons.where(friend: true)).to be_empty
    end
  end

  describe 'other kinds' do
    it 'rejects an unknown kind' do
      import(body.merge('kind' => 'solomonis_party'))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('unknown_kind')
    end

    it 'does not import builds yet' do
      import(body.merge('kind' => 'solomonis_build'))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('unsupported_kind')
    end
  end
end
