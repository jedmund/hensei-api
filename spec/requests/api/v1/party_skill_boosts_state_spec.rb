# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party skill boosts battle state', type: :request do
  let(:party) { create(:party) }

  before do
    create(:weapon_skill_boost_type, key: 'enmity', stacking_rule: 'multiplicative_by_series')
    weapon = create(:weapon, max_skill_level: 15)
    ws = create(:weapon_skill, weapon: weapon)
    create(:weapon_skill_version, weapon_skill: ws, skill_modifier: 'Enmity',
                                  skill_series: 'normal', skill_size: 'big')
    # Enmity curve: 0 at full HP, grows as HP falls.
    create(:weapon_skill_datum, modifier: 'Enmity', boost_type: 'enmity',
                                series: 'normal', size: 'big', sl15: 15.0,
                                formula_type: 'enmity')
    create(:grid_weapon, party: party, weapon: weapon, position: 0, uncap_level: 4)
  end

  def enmity_line(params = {})
    get "/api/v1/parties/#{party.shortcode}/skill_boosts", params: params
    response.parsed_body['lines'].find { |l| l['key'] == 'enmity' }
  end

  it 'defaults to full HP (enmity contributes nothing)' do
    expect(enmity_line).to be_nil
  end

  it 'evaluates HP-scaled skills at the requested hp_percent' do
    low = enmity_line(hp_percent: 1)
    mid = enmity_line(hp_percent: 50)
    expect(low['value']).to be > 0
    expect(low['value']).to be > mid['value']
  end

  it 'clamps and echoes the applied state' do
    get "/api/v1/parties/#{party.shortcode}/skill_boosts",
        params: { hp_percent: 250, turn: -3, foe_element: 'MOON' }
    state = response.parsed_body['state']
    expect(state['hp_percent']).to eq(100.0)
    expect(state['turn']).to eq(1)
    expect(state['foe_element']).not_to eq('moon')
  end

  it 'accepts null as an explicit foe element' do
    get "/api/v1/parties/#{party.shortcode}/skill_boosts", params: { foe_element: 'null' }
    expect(response.parsed_body['state']['foe_element']).to eq('null')
  end
end
