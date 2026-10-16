# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::BefoulmentContributions do
  let(:party) { create(:party) }
  let(:modifier) { create(:weapon_stat_modifier, :befoulment, stat: "atk") }

  def hit_values
    described_class.for_party(party).map { |c| [c.boost_type, c.value] }
  end

  it "shows the modifier's sign whether the strength was stored as a magnitude or signed" do
    create(:grid_weapon, party: party, position: 1, befoulment_modifier: modifier, befoulment_strength: 14.1)
    create(:grid_weapon, party: party, position: 2, befoulment_modifier: modifier, befoulment_strength: -9.9)

    expect(hit_values).to contain_exactly(["atk_hit", -14.1], ["atk_hit", -9.9])
  end
end
