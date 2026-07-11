# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::GridComposition do
  describe ".summarize" do
    it "tallies weapon types, series, named groups, per-id copies, distinct skill types, and omega-skill count" do
      entries = [
        { proficiency: 1, series_slug: "epic", group_slugs: %w[foo], granblue_id: "A",
          modifiers: %w[Might Enmity], omega: false },
        { proficiency: 1, series_slug: "epic", group_slugs: %w[foo bar], granblue_id: "A",
          modifiers: %w[Might], omega: true },
        { proficiency: 2, series_slug: "militis", group_slugs: %w[bar], granblue_id: "B",
          modifiers: %w[Stamina], omega: false }
      ]
      r = described_class.summarize(entries)
      expect(r[:weapon_type_counts]).to eq(1 => 2, 2 => 1)
      expect(r[:weapon_series_counts]).to eq("epic" => 2, "militis" => 1)
      expect(r[:weapon_count_group_counts]).to eq("foo" => 2, "bar" => 2)
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
        weapon_count_group_counts: { "foo" => 5 },
        omega_skill_count: 6
      }
    end

    it "resolves canonical count bases" do
      expect(described_class.count_for_basis("same_weapon_type", weapon: weapon, composition: composition)).to eq(3)
      expect(described_class.count_for_basis("max_same_weapon_type", weapon: weapon, composition: composition)).to eq(4)
      expect(described_class.count_for_basis("distinct_weapon_types", weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis("same_series", weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis("series:epic", weapon: weapon, composition: composition)).to eq(2)
      expect(described_class.count_for_basis("group:foo", weapon: weapon, composition: composition)).to eq(5)
      expect(described_class.count_for_basis("omega_skill", weapon: weapon, composition: composition)).to eq(6)
    end

    it "rejects legacy count bases" do
      expect {
        described_class.count_for_basis("weapon_type", weapon: weapon, composition: composition)
      }.to raise_error(ArgumentError, /Unknown count_basis/)
    end
  end
end
