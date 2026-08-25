# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party skill boosts API', type: :request do
  describe 'GET /api/v1/parties/:shortcode/skill_boosts' do
    let(:party) { create(:party) }

    before do
      create(:weapon_skill_boost_type, key: 'atk', stacking_rule: 'multiplicative_by_series')
      weapon = create(:weapon, max_skill_level: 15, element: 6)
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

    it 'includes Light Grand Sandalphon from the backline in a Zeus grid' do
      summon = create(:summon, element: 6)
      SummonAura.create!(summon_granblue_id: summon.granblue_id, slot: 'main',
                         target: 'normal_frame', uncap_level: 0,
                         transcendence_stage: 0, value: 150)
      create(:grid_summon, party: party, summon: summon, main: true,
                           position: 0, uncap_level: 0)

      sandalphon = create(:character, granblue_id: '3040515000', element: 6,
                                      name_en: 'Sandalphon (Grand)')
      skill = create(:character_skill, :support, character: sandalphon, position: 2)
      version = create(:character_skill_version, character_skill: skill, name_en: 'Selas Arche')
      %w[normal omega].each_with_index do |frame, index|
        create(:skill_effect, character_skill_version: version, status: nil,
                              ordinal: index + 1, effect_type: :weapon_skill_boost,
                              target: :element_allies, frame: frame, element: 'light', amount: 20)
      end
      create(:grid_character, party: party, character: sandalphon, position: 4, uncap_level: 4)

      get "/api/v1/parties/#{party.shortcode}/skill_boosts"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['enhancements']).to include('optimus' => 170.0, 'omega' => 20.0)
      might = json['lines'].find { |line| line['key'] == 'atk' && line['series'] == 'normal' }
      expect(might).to include('value' => 54.0, 'display' => '54%')
    end

    it '404s for an unknown shortcode' do
      get '/api/v1/parties/zzzzzz/skill_boosts'
      expect(response).to have_http_status(:not_found)
    end
  end
end
