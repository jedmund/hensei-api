# frozen_string_literal: true

require 'rails_helper'

# XZq7xW: Fiendspear of Mortality Verboten's Odious Exalto Aquae ("25% boost to Taboo
# Allowater's weapon skills") shows as Water Taboo 25 and adds flat to the Taboo
# enhancement (385 = 180 + 180 + 25 at the exorcision cap).
RSpec.describe 'Odious Exalto' do
  it 'adds its 25 to the Taboo enhancement, unamplified' do
    party = Granblue::GoldenFixture.load('XZq7xW', mode: :replace)
    panel = GridDamage::Calculator.panel(party, state: { foe_element: 'fire' })
    auras = GridDamage::Auras.for_party(party, element: 'water')

    expect(panel[:agg]['odious_exalto'].total).to eq(25.0)
    expect(panel[:enhancements][:taboo]).to eq(auras[:taboo] + 25.0)
  end
end
