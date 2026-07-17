# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party skill boosts battle state', type: :request do
  let(:party) { create(:party) }
  let(:weapon) { create(:weapon, max_skill_level: 15) }
  let(:weapon_skill_version) do
    weapon_skill = create(:weapon_skill, weapon: weapon)
    create(:weapon_skill_version, weapon_skill: weapon_skill, skill_modifier: 'Enmity',
                                  skill_series: 'normal', skill_size: 'big')
  end

  before do
    create(:weapon_skill_boost_type, key: 'enmity', stacking_rule: 'multiplicative_by_series')
    weapon_skill_version
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
        params: { hp_percent: 250, ally_max_hp: 2_000_000, turn: -3, foe_element: 'MOON', arcarum: true }
    state = response.parsed_body['state']
    expect(state['hp_percent']).to eq(100.0)
    expect(state['ally_max_hp']).to eq(999_999.0)
    expect(state['turn']).to eq(1)
    expect(state['foe_element']).not_to eq('moon')
    expect(state['arcarum']).to be(true)
  end

  it 'defaults and echoes arcarum as false' do
    get "/api/v1/parties/#{party.shortcode}/skill_boosts"

    expect(response.parsed_body.dig('state', 'arcarum')).to be(false)
  end

  it 'applies Arcarum-gated effects only when Arcarum is enabled' do
    create(:weapon_skill_boost_type, key: 'dmg_cap_arc', stacking_rule: 'highest_only')
    WeaponSkillEffect.create!(
      weapon_skill_version: weapon_skill_version,
      modifier: 'Test Arcarum',
      boost_type: 'dmg_cap_arc',
      scaling_kind: 'conditional_flat',
      value: 20.0,
      value_unit: 'percent',
      condition: { 'type' => 'arcarum', 'eq' => true },
      stacking: 'highest_only',
      applies_to: 'element_allies'
    )

    get "/api/v1/parties/#{party.shortcode}/skill_boosts", params: { arcarum: false }
    expect(response.parsed_body['lines']).not_to include(a_hash_including('key' => 'dmg_cap_arc'))

    get "/api/v1/parties/#{party.shortcode}/skill_boosts", params: { arcarum: true }
    expect(response.parsed_body['lines']).to include(a_hash_including('key' => 'dmg_cap_arc', 'value' => 20.0))
  end

  it 'accepts null as an explicit foe element' do
    get "/api/v1/parties/#{party.shortcode}/skill_boosts", params: { foe_element: 'null' }
    expect(response.parsed_body['state']['foe_element']).to eq('null')
  end
end
