# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridDamage::PanelState do
  let(:party) { build(:party) }

  before { allow(GridDamage::ElementScope).to receive(:panel_element).with(party).and_return('fire') }

  it 'defaults to full HP on turn 1 against the advantaged foe' do
    expect(described_class.from_params({}, party))
      .to eq(hp_percent: 100.0, turn: 1, foe_element: 'wind', arcarum: false)
  end

  it 'clamps HP, turn and max HP' do
    state = described_class.from_params({ hp_percent: '150', turn: '0', ally_max_hp: '-5' }, party)

    expect(state).to include(hp_percent: 100, turn: 1, ally_max_hp: 0)
  end

  it 'takes a known foe element, including null, and ignores others' do
    expect(described_class.from_params({ foe_element: 'Water' }, party)[:foe_element]).to eq('water')
    expect(described_class.from_params({ foe_element: 'null' }, party)[:foe_element]).to eq('null')
    expect(described_class.from_params({ foe_element: 'plasma' }, party)[:foe_element]).to eq('wind')
  end

  it 'casts arcarum' do
    expect(described_class.from_params({ arcarum: 'true' }, party)[:arcarum]).to be(true)
  end
end
