# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/import/wiki', type: :request do
  include_context 'with a wiki import catalogue'

  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:auth_headers) { json_headers.merge('Authorization' => "Bearer #{access_token.token}") }

  def import(body, headers: json_headers)
    post '/api/v1/import/wiki', params: body.is_a?(String) ? body : body.to_json, headers: headers
  end

  def grid_counts
    [Party.count, GridCharacter.count, GridWeapon.count, GridSummon.count, GridWeaponBullet.count]
  end

  describe 'preview' do
    it 'returns the report and a null party without writing anything' do
      expect { import({ wiki: wiki }) }.not_to(change { grid_counts })

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to eq(%w[party report])
      expect(body['party']).to be_nil
      expect(body['report'].keys).to eq(%w[matched unmatched ambiguous warnings])
      expect(body['report']['matched'].find { |m| m['kind'] == 'weapon' && m['position'] == -1 }).to eq(
        'kind' => 'weapon', 'position' => -1, 'title' => 'WI Ultima Gun (Fire)',
        'item' => { 'id' => ultima_gun.id, 'granblueId' => ultima_gun.granblue_id,
                    'name' => { 'en' => 'WI Ultima Gun', 'ja' => ultima_gun.name_jp }, 'element' => 1 }
      )
    end

    it 'shapes unmatched, ambiguous and warning entries like the contract' do
      create(:character, name_en: 'WI Sandalphon', wiki_en: 'WI Sandalphon')
      create(:character, name_en: 'WI Sandalphon', wiki_en: 'WI Sandalphon', style_swap: true)
      wiki['characters'] += [{ 'position' => 2, 'title' => 'WI Sandalphon' },
                             { 'position' => 3, 'title' => 'Not A Character' }]
      wiki['keys']['opus'] = [nil, 999_999]

      import({ wiki: wiki })

      report = response.parsed_body['report']
      expect(report['unmatched']).to eq([{ 'kind' => 'character', 'position' => 3, 'title' => 'Not A Character' }])
      expect(report['ambiguous'].sole.keys).to eq(%w[kind position title candidates])
      expect(report['ambiguous'].sole['candidates'].first.keys).to eq(%w[id granblueId name element])
      expect(report['warnings']).to eq([{ 'code' => 'unknown_key', 'detail' => 'opus slot 1',
                                         'kind' => 'key', 'position' => 1, 'title' => '999999' }])
    end

    it 'returns an empty report for an empty paste' do
      import({ wiki: { preview: true } })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'party' => nil,
        'report' => { 'matched' => [], 'unmatched' => [], 'ambiguous' => [], 'warnings' => [] }
      )
    end
  end

  describe 'create' do
    before { wiki['preview'] = false }

    it 'reads snake_case keys sent by the web adapter' do
      wiki['job']['full_auto_off'] = wiki['job'].delete('fullAutoOff')

      import({ wiki: wiki })

      expect(Party.find(response.parsed_body.dig('party', 'id')).full_auto_skills).to eq('0' => false, '2' => false)
    end

    it 'creates the party for the signed-in user, rendered like PartiesController#create' do
      expect { import({ wiki: wiki }, headers: auth_headers) }.to change(Party, :count).by(1)

      expect(response).to have_http_status(:ok)
      party = Party.find(response.parsed_body.dig('party', 'id'))
      expect(party.user).to eq(user)
      expected = JSON.parse(Api::V1::PartyBlueprint.render(
                              Party.find(party.id), view: :created, current_user: user, admin_mode: false
                            ))
      rendered = response.parsed_body['party']
      expect(rendered.keys).to match_array(expected.keys)
      expect(rendered['shortcode']).to eq(party.shortcode)
      expect(rendered['edit_key']).to be_nil
      expect(rendered['weapons'].size).to eq(3)
      expect(rendered['characters'].size).to eq(2)
      expect(rendered['summons'].size).to eq(3)
      expect(response.parsed_body['report']['warnings']).to eq([])
    end

    it 'stores the local id on an anonymous party' do
      local_id = SecureRandom.uuid
      wiki['localId'] = local_id

      import({ wiki: wiki })

      expect(Party.find(response.parsed_body.dig('party', 'id')).local_id).to eq(local_id)
    end

    it 'reads local_id as well' do
      local_id = SecureRandom.uuid
      wiki['local_id'] = local_id

      import({ wiki: wiki })

      expect(Party.find(response.parsed_body.dig('party', 'id')).local_id).to eq(local_id)
    end

    it 'ignores the local id for a signed-in user' do
      wiki['localId'] = SecureRandom.uuid

      import({ wiki: wiki }, headers: auth_headers)

      expect(Party.find(response.parsed_body.dig('party', 'id')).local_id).to be_nil
    end

    it 'gives an anonymous party an edit key' do
      import({ wiki: wiki })

      party = Party.find(response.parsed_body.dig('party', 'id'))
      expect(party.user).to be_nil
      expect(response.parsed_body.dig('party', 'edit_key')).to eq(party.edit_key)
      expect(party.edit_key).to be_present
    end

    it 'builds the grid with keys on every series weapon and bullets on the mainhand' do
      import({ wiki: wiki })

      party = Party.find(response.parsed_body.dig('party', 'id'))
      ultimas = party.weapons.where(weapon: [ultima_gun, ultima_sword])
      expect(ultimas.map { |gw| [gw.weapon_key1_id, gw.weapon_key2_id] }.uniq).to eq([[will_key.id, ca_key.id]])
      expect(party.weapons.find_by(position: -1).bullets).to contain_exactly(chaos_legion, chaser)
      expect(party.element).to eq(ultima_gun.element)
    end

    it 'skips a forged bullet and a key from another series but imports the rest' do
      wiki['bullets'] = %w[wi-chaos-legion not-a-bullet]
      wiki['keys']['ultima'] = [915_001, 911_003]

      import({ wiki: wiki })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['report']['warnings']).to contain_exactly(
        { 'code' => 'unknown_bullet', 'detail' => 'not-a-bullet', 'kind' => 'bullet', 'position' => 1,
          'title' => 'not-a-bullet' },
        { 'code' => 'unknown_key', 'detail' => 'ultima slot 0', 'kind' => 'key', 'position' => 0,
          'title' => '915001' }
      )
      party = Party.find(response.parsed_body.dig('party', 'id'))
      expect(party.weapons.find_by(position: -1)).to have_attributes(weapon_key1_id: nil, weapon_key2_id: ca_key.id)
      expect(party.weapons.find_by(position: -1).bullets).to eq([chaos_legion])
    end
  end

  describe 'errors' do
    it 'rejects bodies over 64 KB before parsing' do
      import('x' * (64.kilobytes + 1))

      expect(response).to have_http_status(:payload_too_large)
      expect(response.parsed_body).to eq('error' => 'payload_too_large')
    end

    it 'returns 422 when wiki is missing' do
      import({ team: {} })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('error' => 'invalid_payload', 'detail' => 'wiki must be an object')
    end

    it 'returns 422 for wrong types' do
      import({ wiki: { characters: [{ position: '0', title: 'WI Seofon' }] } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('invalid_payload')
      expect(response.parsed_body['detail']).to eq('characters[0].position must be an integer')
    end

    it 'returns 422 for a local id that is not a string' do
      import({ wiki: { localId: 12 } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['detail']).to eq('localId must be a string')
    end

    it 'returns 422 for a body that is not JSON' do
      import('not json')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('invalid_payload')
    end
  end

  describe 'rate limit' do
    it 'returns 429 once a client is over the limit, counted per client' do
      30.times { import({ wiki: {} }, headers: json_headers.merge('CF-Connecting-IP' => '203.0.113.9')) }
      expect(response).to have_http_status(:ok)

      import({ wiki: {} }, headers: json_headers.merge('CF-Connecting-IP' => '203.0.113.9'))
      expect(response).to have_http_status(:too_many_requests)

      import({ wiki: {} }, headers: json_headers.merge('CF-Connecting-IP' => '198.51.100.7'))
      expect(response).to have_http_status(:ok)
    end
  end
end
