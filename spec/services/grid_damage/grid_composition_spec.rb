# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::GridComposition do
  describe ".summarize" do
    it "tallies weapon types, series, per-id copies, distinct skill types, and omega-skill count" do
      entries = [
        { proficiency: 1, series_slug: "epic", granblue_id: "A", modifiers: %w[Might Enmity], omega: false },
        { proficiency: 1, series_slug: "epic", granblue_id: "A", modifiers: %w[Might], omega: true },
        { proficiency: 2, series_slug: "militis", granblue_id: "B", modifiers: %w[Stamina], omega: false }
      ]
      r = described_class.summarize(entries)
      expect(r[:weapon_type_counts]).to eq(1 => 2, 2 => 1)
      expect(r[:weapon_series_counts]).to eq("epic" => 2, "militis" => 1)
      expect(r[:id_counts]).to eq("A" => 2, "B" => 1)
      expect(r[:distinct_weapon_type_count]).to eq(2)
      expect(r[:max_weapon_type_count]).to eq(2)
      expect(r[:skill_type_count]).to eq(3) # Might, Enmity, Stamina (deduped)
      expect(r[:omega_skill_count]).to eq(1)
    end
  end

  describe ".count_for_basis" do
    let(:series) { instance_double(WeaponSeries, slug: "epic") }
    let(:weapon) { instance_double(Weapon, proficiency: 1, weapon_series: series) }
    let(:composition) do
      {
        weapon_type_counts: { 1 => 3 },
        max_weapon_type_count: 4,
        distinct_weapon_type_count: 2,
        weapon_series_counts: { "epic" => 2 },
        omega_skill_count: 6
      }
    end

    it "resolves canonical count bases" do
      expect(described_class.count_for_basis("same_weapon_type", weapon: weapon, composition: composition)).to eq(3)
      expect(described_class.count_for_basis("max_same_weapon_type", weapon: weapon, composition: composition)).to eq(4)
      expect(described_class.count_for_basis("distinct_weapon_types", weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis("same_series", weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis("series:epic", weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis("omega_skill", weapon: weapon, composition: composition)).to eq(6)
    end

    it "rejects legacy and unsupported count bases" do
      %w[weapon_type group:arbitrary].each do |basis|
        expect {
          described_class.count_for_basis(basis, weapon: weapon, composition: composition)
        }.to raise_error(ArgumentError, /Unknown count_basis/)
      end
    end
  end

  describe ".valid_count_condition?" do
    it "accepts positive canonical thresholds" do
      condition = { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 10 }

      expect(described_class.valid_count_condition?(condition)).to be(true)
    end

    it "rejects legacy types, nonpositive thresholds, and obsolete all flags" do
      conditions = [
        { "type" => "weapon_group_count", "gte" => 0, "all" => true },
        { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 0 },
        { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 10, "all" => true }
      ]

      expect(conditions).to all(satisfy { |condition| !described_class.valid_count_condition?(condition) })
    end
  end
end
