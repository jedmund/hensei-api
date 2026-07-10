# frozen_string_literal: true

require "rails_helper"

# End-to-end wiring of the boost-list orchestrator over a small factory grid:
# data-track resolution → summon-aura amplification → flat sources → key effects
# (≥280 two-pass) → rate caps → main-hand gating. The full-fidelity check against a
# real in-game panel is `rake granblue:validate_panel` (data/panel_references/).
RSpec.describe GridDamage::Calculator do
  let(:party) { create(:party) }
  let(:state) { { turn: 1, hp_percent: 100 } }

  before do
    create(:weapon_skill_boost_type, key: "atk", stacking_rule: "multiplicative_by_series")
    create(:weapon_skill_boost_type, key: "hp")
    create(:weapon_skill_boost_type, key: "ta")
  end

  # A grid weapon whose single skill is (modifier, series, size), backed by a canonical
  # SL-curve for `boosts` (sl15 values). max_skill_level 15 + uncap 4 ⇒ evaluates at SL15.
  # Extra opts: `main_hand_only:` for the version; the rest go to the grid weapon.
  def add_weapon(modifier:, series:, position:, boosts:, size: "big", **opts)
    weapon_series = opts.delete(:weapon_series)
    weapon = create(:weapon, max_skill_level: 15, weapon_series: weapon_series)
    ws = create(:weapon_skill, weapon: weapon)
    create(:weapon_skill_version, weapon_skill: ws, skill_modifier: modifier,
                                  skill_series: series, skill_size: size,
                                  main_hand_only: opts.delete(:main_hand_only) || false)
    boosts.each do |boost_type, sl15|
      unless WeaponSkillDatum.canonical.exists?(modifier: modifier, boost_type: boost_type)
        create(:weapon_skill_datum, modifier: modifier, boost_type: boost_type,
                                    series: series, size: size, sl15: sl15)
      end
    end
    create(:grid_weapon, party: party, weapon: weapon, position: position,
                         uncap_level: 4, **opts)
  end

  def add_main_summon(normal_aura:)
    summon = create(:summon)
    SummonAura.create!(summon_granblue_id: summon.granblue_id, slot: "main",
                       target: "normal_frame", uncap_level: 0, transcendence_stage: 0,
                       value: normal_aura)
    create(:grid_summon, party: party, summon: summon, main: true, position: 0)
  end

  context "with a 100% Optimus aura (enhancement factor 2.0)" do
    before do
      add_main_summon(normal_aura: 100)
      add_weapon(modifier: "Might", series: "normal", position: 0, mainhand: true,
                 boosts: { "atk" => 20.0 })
      add_weapon(modifier: "Aegis", series: "normal", position: 1, boosts: { "hp" => 21.0 })
      add_weapon(modifier: "Bewitching", series: "ex", position: 2, size: "massive",
                 boosts: { "atk" => 30.0 })
    end

    it "amplifies Normal-frame skills by the enhancement and leaves EX flat" do
      result = described_class.boost_list(party, state: state)
      expect(result["atk"].by_series["normal"]).to eq(40.0) # 20 × (1 + 100/100)
      expect(result["atk"].by_series["ex"]).to eq(30.0)     # EX: no aura
    end

    it "amplifies HP by the same enhancement as ATK" do
      expect(described_class.boost_list(party, state: state)["hp"].total).to eq(42.0)
    end

    it "adds weapon-awakening bonuses flat (never amplified)" do
      atk_awakening = create(:awakening, :for_weapon, slug: "weapon-atk")
      party.weapons.find_by(position: 1).update!(awakening: atk_awakening, awakening_level: 4)
      result = described_class.boost_list(party, state: state)
      expect(result["atk"].by_series["normal"]).to eq(80.0) # 40 amplified + 40 flat
    end

    it "clamps rate boosts to their in-game cap" do
      add_weapon(modifier: "Abandon", series: "normal", position: 3, boosts: { "ta" => 40.0 })
      result = described_class.boost_list(party, state: state)
      expect(result["ta"].total).to eq(75.0) # 40 × 2.0 = 80 raw → cap
      expect(result["ta"]).to have_attributes(capped: true, raw: 80.0)
    end

    it "drops main-hand-only skills on non-mainhand weapons" do
      add_weapon(modifier: "Celere", series: "ex", position: 3, main_hand_only: true,
                 boosts: { "atk" => 12.0 })
      expect(described_class.boost_list(party, state: state)["atk"].by_series["ex"]).to eq(30.0)
    end

    it "does not amplify Ancestral weapon skills with summon auras" do
      ancestral = create(:weapon_series, slug: "ancestral", summon_boosted: false)
      add_weapon(modifier: "Fandango", series: "normal", position: 3,
                 boosts: { "atk" => 33.0 }, size: "ancestral", weapon_series: ancestral)

      expect(described_class.boost_list(party, state: state)["atk"].by_series["normal"]).to eq(73.0)
    end
  end

  context "boost_level (≥280) key effects — the two-pass activation" do
    def add_keyed_weapon(position:)
      key = create(:weapon_key, slug: "test-pendulum")
      WeaponSkillEffect.create!(key_slug: "test-pendulum", modifier: "Test Pendulum",
                                boost_type: "atk", series: "ex", scaling_kind: "conditional_flat",
                                value: 40.0, value_unit: "percent", stacking: "additive",
                                applies_to: "element_allies",
                                condition: { "type" => "boost_level", "gte" => 280 })
      add_weapon(modifier: "Might", series: "normal", position: position,
                 boosts: { "atk" => 20.0 }, weapon_key1: key)
    end

    it "activates the key effect when the enhancement reaches 280" do
      add_main_summon(normal_aura: 300)
      add_keyed_weapon(position: 0)
      expect(described_class.boost_list(party, state: state)["atk"].by_series["ex"]).to eq(40.0)
    end

    it "stays inactive below the threshold" do
      add_main_summon(normal_aura: 100)
      add_keyed_weapon(position: 0)
      expect(described_class.boost_list(party, state: state)["atk"].by_series["ex"]).to be_nil
    end
  end
end
