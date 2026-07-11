# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkillEffect, type: :model do
  it "allows canonical count_basis values" do
    effect = described_class.new(modifier: "Voltage", boost_type: "ex_atk_sp",
                                 scaling_kind: "per_grid_count", value: 4,
                                 count_basis: "same_weapon_type")

    expect(effect).to be_valid
  end

  it "rejects legacy count_basis values" do
    effect = described_class.new(modifier: "Voltage", boost_type: "ex_atk_sp",
                                 scaling_kind: "per_grid_count", value: 4,
                                 count_basis: "weapon_type")

    expect(effect).not_to be_valid
    expect(effect.errors[:count_basis]).to include("must be a canonical GridComposition count basis")
  end
end
