# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party skill boosts API', type: :request do
  describe 'GET /api/v1/parties/:shortcode/skill_boosts' do
    let(:party) { create(:party) }

    before do
      create(:weapon_skill_boost_type, key: 'atk', stacking_rule: 'multiplicative_by_series')
      weapon = create(:weapon, max_skill_level: 15)
      ws = create(:weapon_skill, weapon: weapon)
      create(:weapon_skill_version, weapon_skill: ws, skill_modifier: 'Might',
                                    skill_series: 'normal', skill_size: 'big')
      create(:weapon_skill_datum, modifier: 'Might', boost_type: 'atk',
                                  series: 'normal', size: 'big', sl15: 20.0)
      create(:grid_weapon, party: party, weapon: weapon, position: 0, uncap_level: 4)
    end

    it 'returns the panel-shaped boosts for a public party' do
      get "/api/v1/parties/#{party.shortcode}/skill_boosts"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['enhancements']).to include('optimus' => 0.0, 'omega' => 0.0)

      might = json['lines'].find { |l| l['key'] == 'atk' && l['series'] == 'normal' }
      expect(might).to include('label' => 'Might', 'value' => 20.0, 'display' => '20%',
                               'capped' => false)
    end

    it '404s for an unknown shortcode' do
      get '/api/v1/parties/zzzzzz/skill_boosts'
      expect(response).to have_http_status(:not_found)
    end
  end
end
