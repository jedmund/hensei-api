# frozen_string_literal: true

require 'rails_helper'

# Evoking Solomonis reads: the catalogues, the `solomonis` object on the full
# party view, the list summary and the party search filters.
RSpec.describe 'Evoking Solomonis API', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) { { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' } }

  let(:zone) { create(:raid, :solomonis_zone, name_en: 'Allotropic Microcosm', slug: 'allotropic-microcosm') }
  let(:nier) do
    create(:character, :solomonis_evoker, solomonis_zone: zone, name_en: 'Nier', name_jp: 'ニーア',
                                          granblue_id: '3040169000', element: 5)
  end
  let(:caim) do
    create(:character, :solomonis_evoker, solomonis_zone: zone, name_en: 'Caim', name_jp: 'カイム',
                                          granblue_id: '3040164000', element: 4)
  end
  let(:justice) { create(:arcarum_blessing, :justice) }
  let(:justice_level) { create(:arcarum_blessing_level, arcarum_blessing: justice, level: 3, cost: 50) }

  describe 'GET /api/v1/solomonis/route_evokers' do
    it 'lists route-eligible Evokers with their zone, without auth' do
      nier
      create(:character, name_en: 'Not an Evoker')

      get '/api/v1/solomonis/route_evokers'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to include('public')
      evokers = response.parsed_body['route_evokers']
      expect(evokers.size).to eq(1)
      expect(evokers.first).to include(
        'id' => nier.id, 'granblue_id' => '3040169000', 'element' => 5,
        'name' => { 'en' => 'Nier', 'ja' => 'ニーア' }
      )
      expect(evokers.first['zone']).to eq(
        'id' => zone.id, 'slug' => 'allotropic-microcosm', 'name' => { 'en' => 'Allotropic Microcosm', 'ja' => nil }
      )
    end
  end

  describe 'GET /api/v1/solomonis/blessings' do
    it 'returns the cost limit and every blessing with its levels' do
      create(:arcarum_blessing_level, arcarum_blessing: justice, level: 2, cost: 60, scintillas: 49_000)
      justice_level
      tower = create(:arcarum_blessing, :unreleased, slug: 'tower', arcana_number: 16, name_en: 'The Tower')

      get '/api/v1/solomonis/blessings'

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['cost_limit']).to eq(100)
      expect(body['blessings'].pluck('slug')).to eq(%w[justice tower])
      first = body['blessings'].first
      expect(first).to include('id' => justice.id, 'arcana_number' => 11, 'released' => true,
                               'name' => { 'en' => 'Justice', 'ja' => nil })
      expect(first['levels'].pluck('level')).to eq([2, 3])
      expect(first['levels'].first).to include('cost' => 60, 'scintillas' => 49_000,
                                               'description' => { 'en' => 'Effect', 'ja' => nil })
      expect(body['blessings'].last).to include('id' => tower.id, 'released' => false, 'levels' => [])
    end
  end

  describe 'GET /api/v1/solomonis/guide_effects' do
    it 'returns the catalogue, including availability and tags' do
      effect = create(:solomonis_guide_effect, granblue_id: 88, rarity: 'unique', stackable: true,
                                               name_en: 'Bonus DMG ({value})', target_type: 'proficiency',
                                               target_values: [1, 2], availability: 'event',
                                               type_tags: ['offense'], effect_tags: %w[dmg_cap])

      get '/api/v1/solomonis/guide_effects'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['guide_effects']).to contain_exactly(
        'id' => effect.id, 'granblue_id' => 88, 'rarity' => 'unique', 'stackable' => true,
        'name' => { 'en' => 'Bonus DMG ({value})', 'ja' => nil },
        'icon_category' => 1, 'icon_type' => 1, 'target_type' => 'proficiency', 'target_values' => [1, 2],
        'character_id' => nil, 'availability' => 'event', 'type_tags' => ['offense'], 'effect_tags' => ['dmg_cap']
      )
    end
  end

  describe 'raid group content_mode' do
    it 'marks the Solomonis group on raid groups and on a party raid' do
      party = create(:party, :solomonis_build, user: user, route_evoker: nier)
      create(:raid_group)

      get '/api/v1/raid_groups'
      modes = response.parsed_body.to_h { |g| [g['id'], g['content_mode']] }
      expect(modes[zone.group.id]).to eq('solomonis')
      expect(modes.except(zone.group.id).values).to all(be_nil)

      get "/api/v1/parties/#{party.shortcode}", headers: headers
      expect(response.parsed_body.dig('party', 'raid', 'group', 'content_mode')).to eq('solomonis')
    end
  end

  describe 'GET /api/v1/parties/:shortcode' do
    it 'returns the solomonis object and seal state for a build' do
      party = create(:party, :solomonis_build, user: user, route_evoker: nier)
      party.replace_solomonis_blessings!([justice_level])
      create(:grid_weapon, party: party, position: -1, mainhand: true)
      create(:grid_weapon, party: party, position: 2)
      create(:grid_weapon, party: party, position: 5)
      create(:grid_character, party: party, character: nier, position: 0)

      get "/api/v1/parties/#{party.shortcode}", headers: headers

      expect(response).to have_http_status(:ok)
      solomonis = response.parsed_body.dig('party', 'solomonis')
      expect(solomonis).to include(
        'kind' => 'build', 'pledge_level' => 0, 'outcome' => nil, 'bosses_defeated' => nil, 'midboss' => nil,
        'expedition_level' => nil, 'build_party' => nil, 'game_report_id' => nil, 'ended_at' => nil,
        'stats' => {}, 'blessing_cost_limit' => 100, 'blessing_cost_total' => 50, 'guidebook' => []
      )
      expect(solomonis['route_evoker']).to eq('id' => nier.id, 'granblue_id' => '3040169000',
                                              'name' => { 'en' => 'Nier', 'ja' => 'ニーア' }, 'element' => 5)
      expect(solomonis['zone']).to include('id' => zone.id, 'slug' => 'allotropic-microcosm')
      expect(solomonis['blessings']).to eq([{
                                             'blessing' => { 'id' => justice.id, 'slug' => 'justice',
                                                             'arcana_number' => 11,
                                                             'name' => { 'en' => 'Justice', 'ja' => nil } },
                                             'level_id' => justice_level.id, 'level' => 3, 'cost' => 50
                                           }])

      weapons = response.parsed_body.dig('party', 'weapons').index_by { |w| w['position'] }
      expect(weapons.transform_values { |w| w['seal_state'] }).to eq(-1 => 'start', 2 => 'start', 5 => 'sealed')
      expect(weapons[5]['unseal_priority']).to be_nil
      expect(response.parsed_body.dig('party', 'characters', 0, 'brought_by_blessing')).to be(false)
    end

    it 'returns the guidebook and linked build for a run' do
      build = create(:party, :solomonis_build, user: create(:user), route_evoker: nier, visibility: 1)
      run = create(:party, :solomonis_run, user: user, route_evoker: nier)
      run.solomonis_expedition.update!(outcome: 'cleared', bosses_defeated: 2, build_party: build)
      unique = create(:solomonis_guide_effect, :unique, granblue_id: 90)
      normal = create(:solomonis_guide_effect, granblue_id: 3)
      run.replace_solomonis_guide_effects!([
        { solomonis_guide_effect: normal, count: 3 },
        { solomonis_guide_effect: unique, count: 1, display_value: '80%',
          inherited: true, note: 'carried over' }
      ])

      get "/api/v1/parties/#{run.shortcode}", headers: headers

      solomonis = response.parsed_body.dig('party', 'solomonis')
      expect(solomonis).to include('kind' => 'run', 'outcome' => 'cleared', 'bosses_defeated' => 2,
                                   'build_party' => { 'shortcode' => build.shortcode, 'name' => build.name })
      expect(solomonis['guidebook'].map { |e| e.dig('effect', 'granblue_id') }).to eq([90, 3])
      expect(solomonis['guidebook'].first).to include('count' => 1, 'display_value' => '80%',
                                                      'acquired_order' => nil, 'inherited' => true,
                                                      'note' => 'carried over')
      expect(solomonis['guidebook'].first['effect']).to include('availability', 'type_tags', 'effect_tags')
    end

    it 'hides a linked build the viewer cannot see' do
      build = create(:party, :solomonis_build, user: user, route_evoker: nier, visibility: 1)
      run = create(:party, :solomonis_run, user: user, route_evoker: nier)
      run.solomonis_expedition.update!(build_party: build)
      build.update!(visibility: 3)

      get "/api/v1/parties/#{run.shortcode}"

      expect(response.parsed_body.dig('party', 'solomonis', 'build_party')).to be_nil
    end

    it 'returns null solomonis fields on other parties' do
      party = create(:party, user: user)
      create(:grid_weapon, party: party, position: 0)

      get "/api/v1/parties/#{party.shortcode}", headers: headers

      expect(response.parsed_body.dig('party', 'solomonis')).to be_nil
      expect(response.parsed_body.dig('party', 'weapons', 0)).to include('seal_state' => nil,
                                                                         'unseal_priority' => nil)
    end
  end

  describe 'list views and search filters' do
    def listable(party)
      party.update_columns(weapons_count: 5, summons_count: 2)
      party
    end

    let!(:nier_build) { listable(create(:party, :solomonis_build, user: user, route_evoker: nier)) }
    let!(:nier_run) { listable(create(:party, :solomonis_run, user: user, route_evoker: nier)) }
    let!(:caim_build) { listable(create(:party, :solomonis_build, user: user, route_evoker: caim)) }

    before { caim_build.solomonis_expedition.update!(pledge_level: 3) }

    it 'adds the solomonis summary to list items' do
      other = listable(create(:party, user: user))

      get '/api/v1/parties', headers: headers

      results = response.parsed_body['results'].index_by { |p| p['id'] }
      expect(results[nier_run.id]['solomonis']).to eq('kind' => 'run', 'route_evoker_id' => nier.id,
                                                      'pledge_level' => 0)
      expect(results[other.id]['solomonis']).to be_nil
    end

    it 'filters a Solomonis zone by route Evoker, kind and pledge level' do
      get '/api/v1/parties', params: { raid: zone.slug, route_evoker: nier.id }, headers: headers
      expect(response.parsed_body['results'].pluck('id')).to contain_exactly(nier_build.id, nier_run.id)

      get '/api/v1/parties', params: { raid: zone.id, route_evoker: caim.granblue_id }, headers: headers
      expect(response.parsed_body['results'].pluck('id')).to contain_exactly(caim_build.id)

      get '/api/v1/parties', params: { raid: zone.slug, kind: 'run' }, headers: headers
      expect(response.parsed_body['results'].pluck('id')).to contain_exactly(nier_run.id)

      get '/api/v1/parties', params: { raid: zone.slug, pledge_level: '2,3' }, headers: headers
      expect(response.parsed_body['results'].pluck('id')).to contain_exactly(caim_build.id)

      get '/api/v1/parties', params: { raid: zone.slug, kind: 'bogus' }, headers: headers
      expect(response.parsed_body['results']).to be_empty
    end

    it 'ignores the Solomonis filters for other raids' do
      raid = create(:raid)
      party = listable(create(:party, user: user, raid: raid))

      get '/api/v1/parties', params: { raid: raid.id, kind: 'run' }, headers: headers

      expect(response.parsed_body['results'].pluck('id')).to eq([party.id])
    end
  end
end
