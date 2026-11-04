# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Party, '#substitutions?', type: :model do
  let(:party) { create(:party) }
  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:other_weapon) { Weapon.find_by!(granblue_id: '1040912100') }

  it 'is false when the party has no substitutions' do
    create(:grid_weapon, party: party, weapon: weapon)
    expect(party.substitutions?).to be false
  end

  it 'is true once any grid type carries a substitution' do
    gw = create(:grid_weapon, party: party, weapon: weapon)
    sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
    create(:substitution, grid: gw, substitute_grid: sw, position: 0)

    expect(party.substitutions?).to be true
  end

  it 'memoizes per instance' do
    gw = create(:grid_weapon, party: party, weapon: weapon)

    expect(party.substitutions?).to be false

    # A new substitution after the first call should not flip the cached value
    # on the same instance — callers needing fresh state must re-fetch.
    sw = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
    create(:substitution, grid: gw, substitute_grid: sw, position: 0)

    expect(party.substitutions?).to be false
    expect(described_class.find(party.id).substitutions?).to be true
  end
end
