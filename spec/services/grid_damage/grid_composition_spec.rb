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
      expect(r[:weapon_group_count]).to eq(2)
      expect(r[:max_weapon_type_count]).to eq(2)
      expect(r[:skill_type_count]).to eq(3) # Might, Enmity, Stamina (deduped)
      expect(r[:omega_skill_count]).to eq(1)
    end
  end
end
