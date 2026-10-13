# frozen_string_literal: true

require 'rails_helper'

# Evoking Solomonis writes: party[solomonis] on party create/update (D12), the
# whole-list endpoints under a party (D11), the grid item fields and remix.
RSpec.describe 'Evoking Solomonis writes', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  def auth_headers(for_user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: for_user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  let(:headers) { auth_headers(user) }
  let(:other_headers) { auth_headers(other_user) }

  let(:zone) { create(:raid, :solomonis_zone) }
  let(:nier) { create(:character, :solomonis_evoker, solomonis_zone: zone, element: 5) }
  let(:caim) { create(:character, :solomonis_evoker, solomonis_zone: zone, element: 4) }

  let(:justice) { create(:arcarum_blessing, :justice) }
  let(:justice_level) { create(:arcarum_blessing_level, arcarum_blessing: justice, level: 3, cost: 50) }
  let(:hanged_man) { create(:arcarum_blessing, :hanged_man) }
  let(:hanged_man_level) { create(:arcarum_blessing_level, arcarum_blessing: hanged_man, level: 5, cost: 60) }

  let(:party) { create(:party, :solomonis, user: user, route_evoker: nier) }
  let(:others_party) { create(:party, :solomonis, user: other_user, route_evoker: nier) }
  let(:anon_party) do
    party = create(:party, :solomonis, user: nil, route_evoker: nier)
    party.update_columns(edit_key: 'anonsecret')
    party
  end
  let(:anon_headers) { { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'anonsecret' } }

  def body
    response.parsed_body
  end

  describe 'POST /api/v1/parties with party[solomonis]' do
    it 'creates a party in the route Evoker zone and element' do
      post '/api/v1/parties', params: { party: { name: 'Nier party', solomonis: { route_evoker_id: nier.id } } }.to_json,
                              headers: headers

      expect(response).to have_http_status(:created)
      party = Party.find(body.dig('party', 'id'))
      expect(party.raid_id).to eq(zone.id)
      expect(party.element).to eq(5)
      expect(body.dig('party', 'raid', 'id')).to eq(zone.id)
      expect(body.dig('party', 'solomonis')).to include('pledge_level' => 0, 'outcome' => nil)
      expect(body.dig('party', 'solomonis', 'route_evoker', 'id')).to eq(nier.id)
    end

    it 'creates an anonymous party with an edit key' do
      post '/api/v1/parties', params: { party: { solomonis: { route_evoker_id: nier.id } } }.to_json,
                              headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
      expect(body.dig('party', 'edit_key')).to be_present
      expect(body.dig('party', 'solomonis', 'route_evoker', 'id')).to eq(nier.id)
    end

    it 'writes pledge level and outcome and ignores the import-only and ownership fields' do
      post '/api/v1/parties',
           params: { party: { solomonis: { kind: 'run', route_evoker_id: nier.id, pledge_level: 2, outcome: 'miasma_2',
                                           ended_at: '2026-10-11T16:38:00+09:00', game_report_id: 99,
                                           stats: { battle: 3 }, user_id: other_user.id,
                                           party_id: others_party.id } } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      solomonis = body.dig('party', 'solomonis')
      expect(solomonis).to include('pledge_level' => 2, 'outcome' => 'miasma_2', 'ended_at' => nil,
                                   'game_report_id' => nil, 'stats' => {})
      expect(solomonis.keys).not_to include('kind')
      expedition = Party.find(body.dig('party', 'id')).solomonis_expedition
      expect(expedition.user_id).to eq(user.id)
      expect(others_party.reload.solomonis_expedition.pledge_level).to eq(0)
    end

    it 'rejects an unknown outcome' do
      post '/api/v1/parties',
           params: { party: { solomonis: { route_evoker_id: nier.id, outcome: 'failed' } } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['errors'].keys).to include('solomonis.outcome')
    end

    it 'rejects a Solomonis zone without a route Evoker (D12)' do
      expect do
        post '/api/v1/parties', params: { party: { raid_id: zone.id } }.to_json, headers: headers
      end.not_to change(Party, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'solomonis.route_evoker_id')).to be_present
    end

    it 'rejects a character that cannot lead a route' do
      post '/api/v1/parties', params: { party: { solomonis: { route_evoker_id: create(:character).id } } }.to_json,
                              headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['errors'].keys).to include('solomonis.route_evoker_id')
    end

    it 'rejects an unknown route Evoker' do
      post '/api/v1/parties', params: { party: { solomonis: { route_evoker_id: SecureRandom.uuid } } }.to_json,
                              headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['errors'].keys).to include('solomonis.route_evoker_id')
    end

    it 'rejects invalid expedition fields' do
      post '/api/v1/parties', params: { party: { solomonis: { route_evoker_id: nier.id, pledge_level: 9 } } }.to_json,
                              headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['errors'].keys).to include('solomonis.pledge_level')
    end
  end

  describe 'PUT /api/v1/parties/:id with party[solomonis]' do
    it 'updates the expedition and returns the full party' do
      put "/api/v1/parties/#{party.id}", params: { party: { solomonis: { pledge_level: 4, outcome: 'cleared' } } }.to_json,
                                         headers: headers

      expect(response).to have_http_status(:ok)
      expect(body.dig('party', 'solomonis')).to include('pledge_level' => 4, 'outcome' => 'cleared')
      expect(party.reload.solomonis_expedition.pledge_level).to eq(4)

      put "/api/v1/parties/#{party.id}", params: { party: { solomonis: { outcome: nil } } }.to_json, headers: headers
      expect(body.dig('party', 'solomonis', 'outcome')).to be_nil
    end

    it 'moves the raid and element with the route' do
      create(:grid_weapon, party: party, position: 5)

      put "/api/v1/parties/#{party.id}", params: { party: { solomonis: { route_evoker_id: caim.id } } }.to_json,
                                         headers: headers

      expect(response).to have_http_status(:ok)
      expect(party.reload.element).to eq(4)
      expect(body.dig('party', 'solomonis', 'route_evoker', 'id')).to eq(caim.id)
    end

    it 'enters Solomonis from an ordinary party with a route Evoker' do
      party = create(:party, user: user, raid: create(:raid))

      put "/api/v1/parties/#{party.id}", params: { party: { raid_id: zone.id,
                                                            solomonis: { route_evoker_id: nier.id } } }.to_json,
                                         headers: headers

      expect(response).to have_http_status(:ok)
      expect(party.reload).to be_solomonis
    end

    it 'rejects a raid change into a Solomonis zone without a route Evoker (D12)' do
      party = create(:party, user: user, raid: create(:raid))

      put "/api/v1/parties/#{party.id}", params: { party: { raid_id: zone.id } }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['errors']).to eq('solomonis.route_evoker_id' => ['is required to enter an Evoking Solomonis zone'])
      expect(party.reload.raid_id).not_to eq(zone.id)
    end

    it 'leaves Solomonis when the raid moves out of the group' do
      put "/api/v1/parties/#{party.id}", params: { party: { raid_id: create(:raid).id } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body.dig('party', 'solomonis')).to be_nil
    end

    it "rejects someone else's party" do
      put "/api/v1/parties/#{others_party.id}", params: { party: { solomonis: { pledge_level: 4 } } }.to_json,
                                                headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(others_party.reload.solomonis_expedition.pledge_level).to eq(0)
    end

    it 'accepts an edit-key party with its key and rejects a wrong key' do
      put "/api/v1/parties/#{anon_party.id}", params: { party: { solomonis: { pledge_level: 1 } } }.to_json,
                                              headers: anon_headers
      expect(response).to have_http_status(:ok)

      put "/api/v1/parties/#{anon_party.id}", params: { party: { solomonis: { pledge_level: 2 } } }.to_json,
                                              headers: anon_headers.merge('X-Edit-Key' => 'wrong')
      expect(response).to have_http_status(:unauthorized)
      expect(anon_party.reload.solomonis_expedition.pledge_level).to eq(1)
    end
  end

  describe 'PUT /api/v1/parties/:id/blessings' do
    let!(:position_two) { create(:grid_weapon, party: party, position: 2) }

    it 'replaces the loadout and returns the full party with recomputed seal state' do
      expect(position_two.reload.seal_state).to eq('sealed')

      put "/api/v1/parties/#{party.id}/blessings", params: { blessing_level_ids: [justice_level.id] }.to_json,
                                                   headers: headers

      expect(response).to have_http_status(:ok)
      expect(body.dig('party', 'solomonis', 'blessings').map { |b| b['level_id'] }).to eq([justice_level.id])
      expect(body.dig('party', 'solomonis', 'blessing_cost_total')).to eq(50)
      expect(body.dig('party', 'weapons', 0, 'seal_state')).to eq('start')

      put "/api/v1/parties/#{party.id}/blessings", params: { blessing_level_ids: [] }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(body.dig('party', 'solomonis', 'blessings')).to eq([])
      expect(position_two.reload.seal_state).to eq('sealed')
    end

    it 'rejects a loadout over the cost limit' do
      put "/api/v1/parties/#{party.id}/blessings",
          params: { blessing_level_ids: [justice_level.id, hanged_man_level.id] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'blessings').join).to include('over the limit')
      expect(party.party_blessings.reload).to be_empty
    end

    it 'rejects unreleased blessings' do
      tower = create(:arcarum_blessing, :unreleased)
      level = create(:arcarum_blessing_level, arcarum_blessing: tower, cost: 10)

      put "/api/v1/parties/#{party.id}/blessings", params: { blessing_level_ids: [level.id] }.to_json,
                                                   headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'blessings')).to include('must be released')
    end

    it 'rejects unknown or repeated levels and a missing list' do
      put "/api/v1/parties/#{party.id}/blessings", params: { blessing_level_ids: [SecureRandom.uuid] }.to_json,
                                                   headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      put "/api/v1/parties/#{party.id}/blessings",
          params: { blessing_level_ids: [justice_level.id, justice_level.id] }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      put "/api/v1/parties/#{party.id}/blessings", params: {}.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'blessing_level_ids')).to eq(['must be a list'])
    end

    it 'rejects an ordinary party' do
      party = create(:party, user: user)

      put "/api/v1/parties/#{party.id}/blessings", params: { blessing_level_ids: [justice_level.id] }.to_json,
                                                   headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects someone else's party" do
      put "/api/v1/parties/#{others_party.id}/blessings", params: { blessing_level_ids: [justice_level.id] }.to_json,
                                                          headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(others_party.party_blessings.reload).to be_empty
    end

    it 'rejects a logged-out request and a missing party' do
      put "/api/v1/parties/#{party.id}/blessings", params: { blessing_level_ids: [] }.to_json,
                                                   headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)

      put "/api/v1/parties/#{SecureRandom.uuid}/blessings", params: { blessing_level_ids: [] }.to_json,
                                                            headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'accepts an edit-key party' do
      put "/api/v1/parties/#{anon_party.id}/blessings", params: { blessing_level_ids: [justice_level.id] }.to_json,
                                                        headers: anon_headers

      expect(response).to have_http_status(:ok)
      expect(anon_party.party_blessings.reload.size).to eq(1)
    end
  end

  describe 'PUT /api/v1/parties/:id/guide_effects' do
    let(:stackable) { create(:solomonis_guide_effect, granblue_id: 5) }
    let(:unique) { create(:solomonis_guide_effect, :unique, granblue_id: 88, availability: 'character') }

    def guidebook_params
      { guide_effects: [
        { guide_effect_id: stackable.id, count: 3, acquired_order: 2 },
        { guide_effect_id: unique.id, count: 1, display_value: '80%', inherited: true, note: 'from last run',
          acquired_order: 1 }
      ] }
    end

    it 'replaces the guidebook' do
      put "/api/v1/parties/#{party.id}/guide_effects", params: guidebook_params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      guidebook = body.dig('party', 'solomonis', 'guidebook')
      expect(guidebook.map { |e| e.dig('effect', 'id') }).to eq([unique.id, stackable.id])
      expect(guidebook.first).to include('count' => 1, 'display_value' => '80%', 'inherited' => true,
                                         'note' => 'from last run', 'acquired_order' => 1)
      expect(guidebook.first['effect']).to include('availability' => 'character')
      expect(guidebook.last).to include('count' => 3, 'inherited' => false, 'display_value' => nil)

      put "/api/v1/parties/#{party.id}/guide_effects", params: { guide_effects: [] }.to_json, headers: headers
      expect(body.dig('party', 'solomonis', 'guidebook')).to eq([])
    end

    it 'rejects an ordinary party' do
      ordinary = create(:party, user: user)

      put "/api/v1/parties/#{ordinary.id}/guide_effects", params: guidebook_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'guide_effects')).to be_present
    end

    it 'rejects a stack on an effect that cannot stack' do
      put "/api/v1/parties/#{party.id}/guide_effects",
          params: { guide_effects: [{ guide_effect_id: unique.id, count: 2 }] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'guide_effects').join).to include('cannot be stacked')
    end

    it 'rejects unknown and repeated effects and two inherited ones' do
      put "/api/v1/parties/#{party.id}/guide_effects",
          params: { guide_effects: [{ guide_effect_id: SecureRandom.uuid }] }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      put "/api/v1/parties/#{party.id}/guide_effects",
          params: { guide_effects: [{ guide_effect_id: stackable.id }, { guide_effect_id: stackable.id }] }.to_json,
          headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      put "/api/v1/parties/#{party.id}/guide_effects",
          params: { guide_effects: [{ guide_effect_id: stackable.id, inherited: true },
                                    { guide_effect_id: unique.id, inherited: true }] }.to_json,
          headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(party.expedition_guide_effects.reload).to be_empty
    end

    it "rejects someone else's party" do
      put "/api/v1/parties/#{others_party.id}/guide_effects", params: guidebook_params.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(others_party.expedition_guide_effects.reload).to be_empty
    end

    it 'accepts an edit-key party' do
      put "/api/v1/parties/#{anon_party.id}/guide_effects", params: guidebook_params.to_json, headers: anon_headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT /api/v1/parties/:id/unseal_priority' do
    let!(:mainhand) { create(:grid_weapon, party: party, position: -1, mainhand: true) }
    let!(:weapon_five) { create(:grid_weapon, party: party, position: 5) }
    let!(:weapon_six) { create(:grid_weapon, party: party, position: 6) }
    let!(:sub_summon) { create(:grid_summon, party: party, position: 1, summon: create(:summon)) }

    it 'ranks sealed weapons and summons in one list' do
      put "/api/v1/parties/#{party.id}/unseal_priority",
          params: { items: [{ type: 'summon', id: sub_summon.id }, { type: 'weapon', id: weapon_six.id },
                            { type: 'weapon', id: weapon_five.id }] }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      weapons = body.dig('party', 'weapons').index_by { |w| w['position'] }
      expect(weapons[6]['unseal_priority']).to eq(2)
      expect(weapons[5]['unseal_priority']).to eq(3)
      expect(weapons[-1]['unseal_priority']).to be_nil
      expect(body.dig('party', 'summons', 0, 'unseal_priority')).to eq(1)

      put "/api/v1/parties/#{party.id}/unseal_priority", params: { items: [] }.to_json, headers: headers
      expect(weapon_six.reload.unseal_priority).to be_nil
    end

    it 'rejects a starting slot' do
      put "/api/v1/parties/#{party.id}/unseal_priority",
          params: { items: [{ type: 'weapon', id: mainhand.id }] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'unseal_priority')).to be_present
    end

    it "rejects another party's grid item" do
      foreign = create(:grid_weapon, party: others_party, position: 5)

      put "/api/v1/parties/#{party.id}/unseal_priority",
          params: { items: [{ type: 'weapon', id: foreign.id }] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(foreign.reload.unseal_priority).to be_nil
    end

    it 'rejects an unsealed slot' do
      weapon_five.update!(seal_state: 'unsealed')

      put "/api/v1/parties/#{party.id}/unseal_priority",
          params: { items: [{ type: 'weapon', id: weapon_five.id }] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'unseal_priority')).to be_present
    end

    it 'rejects an ordinary party' do
      ordinary = create(:party, user: user)

      put "/api/v1/parties/#{ordinary.id}/unseal_priority", params: { items: [] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects someone else's party" do
      foreign = create(:grid_weapon, party: others_party, position: 5)

      put "/api/v1/parties/#{others_party.id}/unseal_priority",
          params: { items: [{ type: 'weapon', id: foreign.id }] }.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(foreign.reload.unseal_priority).to be_nil
    end

    it 'accepts an edit-key party' do
      weapon = create(:grid_weapon, party: anon_party, position: 5)

      put "/api/v1/parties/#{anon_party.id}/unseal_priority",
          params: { items: [{ type: 'weapon', id: weapon.id }] }.to_json, headers: anon_headers

      expect(response).to have_http_status(:ok)
      expect(weapon.reload.unseal_priority).to eq(1)
    end
  end

  describe 'grid item fields' do
    it 'seals a weapon added outside the starting slots and starts one added in them (D27)' do
      [[5, 'sealed'], [0, 'start']].each do |position, state|
        weapon = create(:weapon)
        post '/api/v1/grid_weapons',
             params: { weapon: { party_id: party.id, weapon_id: weapon.id, position: position,
                                 mainhand: false, uncap_level: 3, transcendence_step: 0 } }.to_json,
             headers: headers

        expect(response).to have_http_status(:created)
        expect(party.weapons.find_by(position: position).seal_state).to eq(state)
      end
    end

    it 'sets seal_state on a weapon and summon' do
      weapon = create(:grid_weapon, party: party, position: 5)
      summon = create(:grid_summon, party: party, position: 1, summon: create(:summon))

      put "/api/v1/grid_weapons/#{weapon.id}", params: { weapon: { seal_state: 'unsealed' } }.to_json,
                                               headers: headers
      expect(response).to have_http_status(:ok)
      expect(body.dig('grid_weapon', 'seal_state')).to eq('unsealed')

      put "/api/v1/grid_summons/#{summon.id}", params: { summon: { seal_state: 'sealed' } }.to_json,
                                               headers: headers
      expect(response).to have_http_status(:ok)
      expect(body.dig('grid_summon', 'seal_state')).to eq('sealed')
    end

    it 'rejects seal_state on a starting slot and start elsewhere' do
      start_weapon = create(:grid_weapon, party: party, position: 0)
      put "/api/v1/grid_weapons/#{start_weapon.id}", params: { weapon: { seal_state: 'sealed' } }.to_json,
                                                     headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'seal_state')).to be_present

      weapon = create(:grid_weapon, party: party, position: 5)
      put "/api/v1/grid_weapons/#{weapon.id}", params: { weapon: { seal_state: 'start' } }.to_json,
                                               headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(weapon.reload.seal_state).to eq('sealed')
    end

    it 'rejects seal_state outside Solomonis' do
      weapon = create(:grid_weapon, party: create(:party, user: user), position: 5)

      put "/api/v1/grid_weapons/#{weapon.id}", params: { weapon: { seal_state: 'sealed' } }.to_json,
                                               headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects seal_state on someone else's party" do
      weapon = create(:grid_weapon, party: others_party, position: 5)
      summon = create(:grid_summon, party: others_party, position: 1, summon: create(:summon))

      put "/api/v1/grid_weapons/#{weapon.id}", params: { weapon: { seal_state: 'unsealed' } }.to_json,
                                               headers: headers
      expect(response).to have_http_status(:unauthorized)
      put "/api/v1/grid_summons/#{summon.id}", params: { summon: { seal_state: 'unsealed' } }.to_json,
                                               headers: headers
      expect(response).to have_http_status(:unauthorized)
      expect(weapon.reload.seal_state).to eq('sealed')
      expect(summon.reload.seal_state).to eq('sealed')
    end

    it 'marks the character brought by The Hanged Man' do
      party.replace_solomonis_blessings!([hanged_man_level])
      ally = create(:grid_character, party: party, character: create(:character), position: 1)

      put "/api/v1/grid_characters/#{ally.id}", params: { character: { brought_by_blessing: true } }.to_json,
                                                headers: headers

      expect(response).to have_http_status(:ok)
      expect(body.dig('grid_character', 'brought_by_blessing')).to be(true)
    end

    it 'rejects brought_by_blessing without The Hanged Man' do
      ally = create(:grid_character, party: party, character: create(:character), position: 1)

      put "/api/v1/grid_characters/#{ally.id}", params: { character: { brought_by_blessing: true } }.to_json,
                                                headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body.dig('errors', 'brought_by_blessing')).to be_present
    end

    it "rejects brought_by_blessing on someone else's party" do
      others_party.replace_solomonis_blessings!([hanged_man_level])
      ally = create(:grid_character, party: others_party, character: create(:character), position: 1)

      put "/api/v1/grid_characters/#{ally.id}", params: { character: { brought_by_blessing: true } }.to_json,
                                                headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(ally.reload.brought_by_blessing).to be(false)
    end
  end

  describe 'POST /api/v1/parties/:shortcode/remix' do
    it 'keeps Evoker, pledge, blessings, seals and unseal priority but not the results or guidebook' do
      party.solomonis_expedition.update!(pledge_level: 3, outcome: 'cleared', game_report_id: 381_099,
                                         ended_at: Time.current, stats: { 'battle' => 3 })
      party.replace_solomonis_blessings!([justice_level])
      party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: create(:solomonis_guide_effect), count: 1 }])
      create(:grid_weapon, party: party, position: 2)
      ranked = create(:grid_weapon, party: party, position: 5)
      create(:grid_weapon, party: party, position: 6, seal_state: 'unsealed')
      party.replace_unseal_priority!([{ type: 'weapon', id: ranked.id }])

      post "/api/v1/parties/#{party.shortcode}/remix", headers: other_headers

      expect(response).to have_http_status(:created)
      solomonis = body.dig('party', 'solomonis')
      expect(solomonis).to include('pledge_level' => 3, 'outcome' => nil, 'game_report_id' => nil,
                                   'ended_at' => nil, 'stats' => {}, 'guidebook' => [])
      expect(solomonis.dig('route_evoker', 'id')).to eq(nier.id)
      expect(solomonis['blessings'].map { |b| b['level_id'] }).to eq([justice_level.id])
      weapons = body.dig('party', 'weapons').index_by { |w| w['position'] }
      expect(weapons[2]['seal_state']).to eq('start')
      expect(weapons[5]).to include('seal_state' => 'sealed', 'unseal_priority' => 1)
      expect(weapons[6]).to include('seal_state' => 'unsealed', 'unseal_priority' => nil)
      expect(Party.find(body.dig('party', 'id')).solomonis_expedition.user_id).to eq(other_user.id)
      expect(party.reload.solomonis_expedition.outcome).to eq('cleared')
    end
  end
end
