# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkillEffect, type: :model do
  it "allows canonical count_basis values" do
    effect = described_class.new(modifier: "Voltage", boost_type: "ex_atk_sp",
                                 scaling_kind: "per_grid_count", value: 4,
                                 count_basis: "same_weapon_type")

    expect(effect).to be_valid
  end

  it "rejects legacy or unsupported count_basis values" do
    %w[weapon_type group:arbitrary].each do |basis|
      effect = described_class.new(modifier: "Voltage", boost_type: "ex_atk_sp",
                                   scaling_kind: "per_grid_count", value: 4,
                                   count_basis: basis)

      expect(effect).not_to be_valid
      expect(effect.errors[:count_basis]).to include("must be a canonical GridComposition count basis")
    end
  end

  it "rejects legacy or tautological count conditions" do
    conditions = [
      { "type" => "weapon_group_count", "gte" => 0, "all" => true },
      { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 0 },
      { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 10, "all" => true }
    ]

    conditions.each do |condition|
      effect = described_class.new(modifier: "Heroic Tale", boost_type: "dmg_cap",
                                   scaling_kind: "conditional_flat", value: 10, condition: condition)
      expect(effect).not_to be_valid
      expect(effect.errors[:condition]).to include("must use a canonical positive count-basis threshold")
    end
  end
end
