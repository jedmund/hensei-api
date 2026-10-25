# frozen_string_literal: true

require 'rails_helper'

# POST /import with kind solomonis_party: the game's Evoking Solomonis party
# deck (spec/fixtures/solomonis/party-deck.json, Fraux deck 1) into a new party.
RSpec.describe 'ImportController Evoking Solomonis parties', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:deck) { JSON.parse(Rails.root.join('spec/fixtures/solomonis/party-deck.json').read).except('_note') }
  let(:body) { { 'kind' => 'solomonis_party', 'solomonis' => { 'deck' => deck } } }

  # A uid planted in the player's param block, to prove it's never kept.
  let(:uid) { 987_654_321 }

  # Slot numbers in the fixture whose weapons sit in the extra positions (9–11).
  let(:extra_slots) { %w[11 12 13] }

  let!(:fraux) do
    character = Character.find_by!(granblue_id: '3040161000')
    zone = character.solomonis_zone || create(:raid, :solomonis_zone)
    character.update!(solomonis_zone: zone, element: 1)
    character
  end
  let!(:job) { create(:job, granblue_id: '300301') }
  let!(:skill) { create(:job_skill, job: job, name_en: 'Dual Arts') }

  def auth_headers_for(owner)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: owner.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def import(payload = body, as: headers)
    post '/api/v1/import', params: payload.to_json, headers: as
  end

  def imported_party
    Party.find(response.parsed_body['party_id'])
  end

  def pc
    deck['deck']['pc']
  end

  # The real blessing catalogue, as the data migration seeds it.
  before { ActiveRecord::Migration.suppress_messages { LoadSolomonisBlessings.new.up } }

  # Every weapon and summon in the fixture, able to take the uncaps its level
  # implies.
  before do
    pc['weapons'].each do |slot, entry|
      id = entry['master']['id']
      weapon = Weapon.find_by(granblue_id: id) || create(:weapon, granblue_id: id, name_en: entry['master']['name'])
      weapon.update!(flb: true, ulb: true, transcendence: true, extra: extra_slots.include?(slot) || weapon.extra,
                     extra_prerequisite: nil)
    end
    (pc['summons'].values + pc['sub_summons'].values).each do |entry|
      id = entry['master']['id']
      summon = Summon.find_by(granblue_id: id) || create(:summon, granblue_id: id, name_en: entry['master']['name'])
      summon.update!(flb: true, ulb: true, transcendence: true,
                     subaura: summon.subaura || pc['sub_summons'].value?(entry))
    end
  end

  describe 'POST /api/v1/import with kind solomonis_party' do
    it 'imports the deck as a new Solomonis party' do
      expect { import }.to change(Party, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.keys).to contain_exactly('party_id', 'shortcode', 'warnings')
      expect(response.parsed_body['warnings']).to eq([])

      party = imported_party
      expect(party).to have_attributes(user: user, name: 'Fraux Party 1', raid_id: fraux.solomonis_zone_id,
                                       element: fraux.element, job: job, skill3: skill)
      expect(party.shortcode).to eq(response.parsed_body['shortcode'])
      expect(party.solomonis_expedition).to have_attributes(route_evoker: fraux, pledge_level: 0, outcome: nil,
                                                            game_report_id: nil, ended_at: nil, stats: {})
      expect(party.characters.map(&:character)).to eq([fraux])
      expect(party.characters.first).to have_attributes(position: 0, uncap_level: 5, transcendence_step: 0)
      expect(party.expedition_guide_effects).to be_empty
    end

    it 'takes uncaps from levels and evolution' do
      import

      weapons = imported_party.weapons.index_by(&:position)
      expect(weapons.keys).to match_array((-1..11).to_a)
      expect(imported_party.extra).to be(true)
      expect(weapons[-1]).to have_attributes(uncap_level: 6, transcendence_step: 5, mainhand: true)
      expect(weapons[0]).to have_attributes(uncap_level: 4, transcendence_step: 0)
      expect(weapons[9]).to have_attributes(uncap_level: 5, transcendence_step: 0)

      summons = imported_party.summons.index_by(&:position)
      expect(summons.keys).to match_array((-1..5).to_a)
      expect(summons[-1]).to have_attributes(main: true, uncap_level: 6, transcendence_step: 5)
      expect(summons[3]).to have_attributes(uncap_level: 5)
      expect(summons[4]).to have_attributes(uncap_level: 4)
    end

    it 'imports the equipped blessings by name and level' do
      import

      levels = imported_party.party_blessings.includes(:arcarum_blessing, :arcarum_blessing_level)
                             .map { |pb| [pb.slug, pb.arcarum_blessing_level.level] }
      expect(levels).to contain_exactly(['justice', 2], ['death', 8])
      expect(imported_party.solomonis_blessing_cost_total).to eq(deck.dig('deck', 'blessing_cost_info', 'total_cost'))
    end

    it 'matches blessings by order when the name is unknown' do
      deck['deck']['blessing']['1']['name'] = 'ジャスティス?'
      import

      expect(imported_party.party_blessings.map(&:slug)).to contain_exactly('justice', 'death')
    end

    it 'skips a blessing level Hensei does not have, with a warning' do
      deck['deck']['blessing']['3']['level'] = 12
      import

      expect(response).to have_http_status(:created)
      expect(imported_party.party_blessings.map(&:slug)).to eq(['justice'])
      expect(response.parsed_body['warnings']).to eq(['Death has no level 12; skipped'])
    end

    it 'seals the locked weapons and summons and starts the rest' do
      import

      weapons = imported_party.weapons.order(:position).to_h { |w| [w.position, w.seal_state] }
      # Slots 1–4 are open in the deck: the mainhand, 0, 1 and Justice's 2.
      expect(weapons.values_at(-1, 0, 1, 2)).to all(eq('start'))
      expect(weapons.values_at(*(3..11))).to all(eq('sealed'))

      summons = imported_party.summons.order(:position).to_h { |s| [s.position, s.seal_state] }
      expect(summons).to eq(-1 => 'start', 0 => 'sealed', 1 => 'sealed', 2 => 'sealed', 3 => 'sealed',
                            4 => 'sealed', 5 => 'sealed')
      expect(imported_party.weapons.pluck(:unseal_priority) + imported_party.summons.pluck(:unseal_priority))
        .to all(be_nil)
    end

    it 'marks open slots outside the starting ones unsealed' do
      pc['weapons']['8']['is_position_locked'] = false
      pc['sub_summons']['1']['is_position_locked'] = false
      deck['deck']['blessing']['1']['is_used'] = false
      import

      expect(imported_party.weapons.find_by(position: 6).seal_state).to eq('unsealed')
      expect(imported_party.weapons.find_by(position: 2).seal_state).to eq('unsealed')
      expect(imported_party.summons.find_by(position: 4).seal_state).to eq('unsealed')
    end

    it 'marks only the summon whose ID matches quick_user_summon_id as quick' do
      import

      quick = imported_party.summons.select(&:quick_summon)
      expect(quick.map(&:position)).to eq([-1])
    end

    it 'marks no quick summon when the deck has none, even for summons without IDs' do
      pc.delete('quick_user_summon_id')
      pc['summons'].each_value { |entry| entry['param'].delete('id') }
      import

      expect(response).to have_http_status(:created)
      expect(imported_party.summons.where(quick_summon: true)).to be_empty
    end

    it 'never imports a support summon' do
      pc['damage_info'] = { 'summon_name' => Summon.find_by!(granblue_id: '2040094000').name_en }
      import

      expect(imported_party.summons.where(friend: true)).to be_empty
    end

    it "never stores or logs the player's uid" do
      pc['param']['id'] = uid
      import

      expect(response).to have_http_status(:created)
      expect(request.filtered_parameters.dig('solomonis', 'deck', 'deck', 'pc', 'param', 'id')).to eq('[FILTERED]')
      party = imported_party
      stored = [party, party.solomonis_expedition, *party.weapons, *party.summons, *party.characters,
                *CollectionWeapon.where(user: user), *CollectionSummon.where(user: user),
                *CollectionCharacter.where(user: user)].map { |record| record.attributes.to_json }
      expect(stored.join).not_to include(uid.to_s)
    end

    it 'takes visibility, name and playlists from the request' do
      playlist = create(:playlist, user: user)
      import(body.merge('visibility' => 3, 'name' => 'My Fraux', 'playlist_ids' => [playlist.id]))

      expect(imported_party).to have_attributes(visibility: 3, name: 'My Fraux')
      expect(imported_party.playlists).to contain_exactly(playlist)
    end

    it "falls back to the deck's name when the request's name is blank" do
      import(body.merge('name' => '  '))

      expect(imported_party.name).to eq('Fraux Party 1')
    end

    it 'creates a new party each time' do
      import
      expect { import }.to change(Party, :count).by(1)
    end

    context 'when the Evoker is not in the first slot' do
      let(:ally) { create(:character) }
      let(:ally_slot) do
        deck['deck']['npc']['1'].deep_dup.merge('is_fix_evoker_npc' => false).tap do |slot|
          slot['master'] = slot['master'].merge('id' => ally.granblue_id, 'character_id' => '9999', 'name' => 'Ally')
        end
      end

      before do
        deck['deck']['npc']['3'] = deck['deck']['npc']['1']
        deck['deck']['npc']['1'] = ally_slot
      end

      it 'takes the route Evoker from the character matching the deck group' do
        expect { import }.to change(Party, :count).by(1)

        party = imported_party
        expect(party.solomonis_expedition.route_evoker).to eq(fraux)
        expect(party).to have_attributes(raid_id: fraux.solomonis_zone_id, element: fraux.element)
        expect(party.characters.order(:position).map { |c| [c.position, c.character] })
          .to eq([[0, ally], [2, fraux]])
      end

      it 'falls back to the slot marked as the fixed Evoker without a deck group' do
        deck['deck'].delete('combination_group_id')
        import

        expect(response).to have_http_status(:created)
        expect(imported_party.solomonis_expedition.route_evoker).to eq(fraux)
      end

      it 'prefers the deck group over the fixed-Evoker mark' do
        deck['deck']['npc']['1']['is_fix_evoker_npc'] = true
        deck['deck']['npc']['3']['is_fix_evoker_npc'] = false
        import

        expect(response).to have_http_status(:created)
        expect(imported_party.solomonis_expedition.route_evoker).to eq(fraux)
      end

      it 'marks the ally as brought by The Hanged Man when it is equipped' do
        deck['deck']['blessing'].each_value { |entry| entry['is_used'] = entry['name'] == 'The Hanged Man' }
        import

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['warnings']).to eq([])
        brought = imported_party.characters.to_h { |c| [c.character, c.brought_by_blessing] }
        expect(brought).to eq(ally => true, fraux => false)
      end

      it 'marks no ally without The Hanged Man' do
        import

        expect(imported_party.characters.map(&:brought_by_blessing)).to all(be(false))
      end
    end

    it "rejects a deck whose Evoker isn't a route Evoker" do
      deck['deck']['npc']['1']['master']['id'] = create(:character).granblue_id

      expect { import }.not_to change(Party, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('unknown_route_evoker')
    end

    it 'treats a malformed Evoker slot as an unknown Evoker' do
      ['x', 3, [1], { 'master' => 'x' }, { 'master' => [1] }].each do |slot|
        deck['deck']['npc']['1'] = slot
        import

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to eq('unknown_route_evoker')
      end
    end

    it 'skips a blessing whose level is not a number, with a warning' do
      deck['deck']['blessing']['3']['level'] = { 'a' => 1 }
      import

      expect(response).to have_http_status(:created)
      expect(imported_party.party_blessings.map(&:slug)).to eq(['justice'])
      expect(response.parsed_body['warnings']).to eq(['Death has no level {"a" => 1}; skipped'])
    end

    it 'uses the default visibility when visibility is not a number' do
      user.update!(default_import_visibility: 2)
      [{ 'a' => 1 }, [3], '3x'].each do |visibility|
        import(body.merge('visibility' => visibility))

        expect(response).to have_http_status(:created)
        expect(imported_party.visibility).to eq(2)
      end
    end

    it 'rejects a body that is not a party deck' do
      import(body.merge('solomonis' => { 'deck' => { 'deck' => { 'pc' => {} } } }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('invalid_data')
    end

    it 'rejects a payload that is too large' do
      deck['padding'] = 'x' * 1.megabyte

      expect { import }.not_to change(Party, :count)
      expect(response).to have_http_status(:payload_too_large)
    end

    it 'checks the size before parsing the body' do
      post '/api/v1/import', params: 'x' * (1.megabyte + 1), headers: headers

      expect(response).to have_http_status(:payload_too_large)
    end

    it 'requires a signed-in user' do
      expect { import(body, as: { 'Content-Type' => 'application/json' }) }.not_to change(Party, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
