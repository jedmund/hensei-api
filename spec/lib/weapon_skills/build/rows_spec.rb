# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::Build::Rows do
  let(:registry_class) { WeaponSkills::Build::Rows::Registry }
  let(:curve) { registry_class::Curve }

  def curve_row(modifier, boost_type, size, sl15, **rest)
    curve.new(modifier: modifier, boost_type: boost_type, size: size, sl15: sl15,
              series: rest.fetch(:series, "normal"), formula_type: rest.fetch(:formula_type, "flat"),
              **rest.slice(:sl1, :sl10, :sl20, :sl25, :coefficient, :max_value))
  end

  let(:data) do
    [
      curve_row("Tyranny", "atk", "big", 18.0, sl1: 6.0, sl10: 15.0),
      curve_row("Tyranny", "hp", "small", -5.0),
      # the base family for atk (BASE_FAMILIES): the fallback, never Tyranny's own
      curve_row("Might", "atk", "big", 20.0, sl1: 7.0, sl10: 16.0),
      # what a skill with no aura in its text (series "ex") falls back to
      curve_row("Might", "atk", "big", 18.0, series: "ex", sl1: 6.0, sl10: 15.0, sl20: 21.0),
      curve_row("Stamina", "stamina", "medium", nil, formula_type: "stamina", coefficient: 65.0),
      curve_row("Stamina", "stamina", "medium", nil, series: "omega", formula_type: "stamina", coefficient: 60.4),
      curve_row("Celere", "critical", "big", 10.0, sl1: 2.0),
      curve_row("Verity", "critical", "big", 10.0, sl1: 2.0, sl10: 6.0)
    ]
  end
  let(:effects) { [registry_class::Effect.new(modifier: "Voltage", boost_type: "ex_atk_sp")] }
  let(:registry) { registry_class.new(data: data, effects: effects) }

  # In-memory CurationView double (same duck type as WeaponSkills::Build::CurationView).
  let(:curation) do
    Class.new do
      def initialize(curated: [], suppressed: [], pinned: false)
        @curated = curated.to_set.freeze
        @suppressed = suppressed.to_set.freeze
        @pinned = pinned
      end

      def curated_boost_types(_version) = @curated
      def suppressed(_version) = @suppressed
      def modifier_pinned?(_version) = @pinned
    end
  end

  def version(name, modifier: nil, series: "normal", size: nil)
    WeaponSkills::BuildResult::Version.new(weapon_granblue_id: "1040000000", position: 0, ordinal: 0,
                                           skill_name_en: name, skill_modifier: modifier,
                                           skill_series: series, skill_size: size)
  end

  def compile(ver, text, view: curation.new, notes: nil, reg: registry)
    described_class.compile(ver, text: text, registry: reg, curation: view, notes: notes)
  end

  describe "SL-scaled clauses" do
    it "takes the value from the version's own family curve, not the strongest curve for the size" do
      rows = described_class.call(version("Hoarfrost's Tyranny", modifier: "Tyranny", size: "small"),
                                  text: "Big boost to water allies' ATK", registry: registry, curation: curation.new)
      expect(rows.map(&:kind)).to eq([:datum])
      expect(rows.first.attributes).to include(modifier: "Hoarfrost's Tyranny", boost_type: "atk", size: "big",
                                               series: "normal", sl15: 18.0, sl1: 6.0, aura_boostable: false)
    end

    it "falls back to the base family's curve (Might for ATK) when the skill has no family" do
      rows = compile(version("Unknown Edge"), "Big boost to ATK").rows
      expect(rows.first.attributes).to include(series: "ex", sl15: 18.0, sl20: 21.0, provenance: "fallback:Might/ex")
      rows = compile(version("Inferno's Edge"), "Big boost to fire allies' ATK").rows
      expect(rows.first.attributes).to include(series: "normal", sl15: 20.0, provenance: "fallback:Might/normal")
    end

    it "leaves provenance off a row from the skill's own family curve" do
      rows = compile(version("Hoarfrost's Tyranny", modifier: "Tyranny", size: "small"), "Big boost to ATK").rows
      expect(rows.first.attributes).not_to have_key(:provenance)
    end

    it "breaks a canonical_curve tie (one family, two series) by the clause's series" do
      rows = compile(version("Whirlwind's Verve", modifier: "Verve", size: "medium"),
                     "Medium boost to wind allies' ATK based on how high HP is").rows
      stamina = rows.find { |r| r.boost_type == "stamina" }
      expect(stamina.attributes).to include(coefficient: 65.0, formula_type: "stamina")
    end

    it "breaks a canonical_curve tie between families by base family, then completeness, then name" do
      picked = registry.canonical_curve(boost_type: "critical", size: "big", formula_type: "flat", series: "normal")
      expect(picked.modifier).to eq("Verity")

      defs = registry_class.new(data: [curve_row("Bulwark", "def", "big", 10.0),
                                       curve_row("Rampart", "def", "big", 10.0, sl1: 2.0),
                                       curve_row("Aegisguard", "def", "big", 9.0, sl1: 2.0)], effects: [])
      picked = defs.canonical_curve(boost_type: "def", size: "big", formula_type: "flat", series: "normal")
      expect(picked.modifier).to eq("Aegisguard")
    end

    it "skips boost types the family's canonical rows already cover" do
      rows = compile(version("Hoarfrost's Tyranny", modifier: "Tyranny", size: "big"), "Big boost to ATK").rows
      expect(rows).to be_empty
    end
  end

  # Captures C1UGnK, FaJB80 and GmPPWw: EX ATK Big skills with no family follow the EX Might
  # Big row; the six "Armed <element>" skills follow their own 6/15/18/20.
  describe "fallback curves" do
    let(:ex_might) { curve_row("Might", "atk", "big", 18.0, series: "ex", sl1: 6.0, sl10: 15.0, sl20: 21.0) }
    let(:taboo) { curve_row("Tyranny", "atk", "big", 21.6, series: "taboo", sl1: 7.2, sl10: 18.0) }
    let(:normal_might) { curve_row("Might", "atk", "big", 18.0, sl1: 6.0, sl10: 15.0, sl20: 20.0) }
    let(:ex_registry) { registry_class.new(data: [taboo, normal_might, ex_might], effects: []) }

    def fallback(reg, series, boost_type: "atk", size: "big")
      reg.canonical_curve(boost_type: boost_type, size: size, formula_type: "flat", series: series)
    end

    it "takes the skill's own series over a larger curve from another series" do
      expect(fallback(ex_registry, "ex")).to eq(ex_might)
      expect(fallback(ex_registry, "normal")).to eq(normal_might)
    end

    it "never gives an EX skill a Taboo curve" do
      only_taboo = registry_class.new(data: [taboo], effects: [])
      expect(fallback(only_taboo, "ex")).to be_nil
      expect(fallback(only_taboo, "odious")).to eq(taboo)
    end

    describe "the Optimus last resort (non-ATK boost types)" do
      let(:da_taboo) { curve_row("Trium", "da", "medium", 6.0, series: "taboo", sl1: 1.0, sl10: 4.2) }
      let(:da_omega) { curve_row("Heroism", "da", "medium", 9.0, series: "omega", sl1: 2.0, sl10: 6.0) }
      let(:da_normal_omega) { curve_row("Trium", "da", "medium", 5.0, series: "normal_omega", sl1: 0.8, sl10: 3.5) }
      let(:da_normal) { curve_row("Dual-Edge", "da", "medium", 5.0, sl1: 0.8, sl10: 3.5, sl20: 6.0) }

      it "gives an EX DA skill with no EX curve the normal DA curve, then normal_omega's" do
        reg = registry_class.new(data: [da_taboo, da_omega, da_normal_omega, da_normal], effects: [])
        expect(fallback(reg, "ex", boost_type: "da", size: "medium")).to eq(da_normal)
        reg = registry_class.new(data: [da_taboo, da_omega, da_normal_omega], effects: [])
        expect(fallback(reg, "ex", boost_type: "da", size: "medium")).to eq(da_normal_omega)
        expect(fallback(reg, "odious", boost_type: "da", size: "medium")).to eq(da_taboo) # own series first
      end

      it "never uses a Taboo or omega-only curve" do
        reg = registry_class.new(data: [da_taboo, da_omega], effects: [])
        expect(fallback(reg, "ex", boost_type: "da", size: "medium")).to be_nil
      end

      it "never reaches an EX curve for an Odious skill" do
        ex_hp = curve_row("Aegis", "hp", "small", 14.5, series: "ex", sl1: 3.0, sl10: 12.0)
        expect(fallback(registry_class.new(data: [ex_hp], effects: []), "odious", boost_type: "hp", size: "small"))
          .to be_nil
      end

      it "marks the row's provenance" do
        reg = registry_class.new(data: [da_taboo, da_normal_omega], effects: [])
        rows = compile(version("Climate Control", series: "ex"), "Medium boost to all allies' double attack rate",
                       reg: reg).rows
        expect(rows.first.attributes).to include(boost_type: "da", sl15: 5.0,
                                                 provenance: "fallback:Trium/normal_omega (Optimus last resort)")
        expect(described_class.last_resort_row?(rows.first)).to be(true)
      end
    end

    it "keeps ATK strict: no curve in a compatible series means no row and a warning" do
      result = compile(version("Clouds of Nightfall", series: "ex"), "Big boost to dark allies' ATK",
                       reg: registry_class.new(data: [taboo, normal_might], effects: []))
      expect(result.rows).to be_empty
      expect(result.warnings).to include(a_string_matching(%r{no curve for atk/big in series "ex"}))
    end

    it "copies the EX Might Big row and records it in provenance" do
      rows = compile(version("Clouds of Nightfall", series: "ex"), "Big boost to dark allies' ATK", reg: ex_registry).rows
      expect(rows.first.attributes).to include(sl1: 6.0, sl10: 15.0, sl15: 18.0, sl20: 21.0,
                                               provenance: "fallback:Might/ex")
    end

    it "keeps another family's fallback when a family with larger values is added" do
      bigger = [
        curve_row("Zealotry", "atk", "big", 30.0, series: "ex", sl1: 10.0, sl10: 25.0, sl20: 35.0, sl25: 40.0),
        curve_row("Abyss", "atk", "big", 30.0, series: "ex", sl1: 10.0, sl10: 25.0, sl20: 35.0, sl25: 40.0),
        curve_row("Fandango", "atk", "big", 25.0, series: "taboo", sl1: 9.0, sl10: 20.0, sl20: 28.0)
      ]
      grown = registry_class.new(data: ex_registry.data + bigger, effects: [])
      expect(fallback(grown, "ex")).to eq(ex_might)
      expect(fallback(grown, "normal")).to eq(normal_might)
    end

    describe "the Armed family" do
      let(:armed) { curve_row("Armed", "atk", "big", 18.0, series: "ex", sl1: 6.0, sl10: 15.0, sl20: 20.0) }
      let(:armed_registry) { registry_class.new(data: [taboo, ex_might, armed], effects: []) }

      it "resolves every Armed <element> skill to its own curve, not a fallback" do
        %w[Blaze Flood Gale Grounds Shadow Shine].each do |element|
          result = compile(version("Armed #{element}", series: "ex"), "Big boost to allies' ATK", reg: armed_registry)
          expect(result.version.skill_modifier).to eq("Armed")
          expect(result.rows).to be_empty # the family's canonical row covers atk
          expect(armed_registry.for_skill(modifier: "Armed", series: "ex", size: result.version.skill_size))
            .to contain_exactly(armed)
        end
      end

      it "doesn't move other EX ATK Big skills off EX Might" do
        expect(fallback(armed_registry, "ex")).to eq(ex_might)
      end

      it "is a cited canonical overlay row (6/15/18/20, EX, big)" do
        overlay = JSON.parse(Rails.root.join("data/weapon_skill_curation/_canonical.json").read)
        entry = overlay["data"].find { |e| e["modifier"] == "Armed" }
        expect(entry).to include("boost_type" => "atk", "series" => "ex", "size" => "big", "sl1" => 6.0,
                                 "sl10" => 15.0, "sl15" => 18.0, "sl20" => 20.0)
        expect(entry["provenance"]).to include("C1UGnK", "FaJB80", "Clarion")
      end
    end
  end

  describe "curation" do
    let(:text) { "Big boost to ATK and 10% boost to critical hit rate" }

    it "never derives a row for a suppressed boost type" do
      rows = compile(version("Unknown Edge"), text, view: curation.new(suppressed: ["atk"])).rows
      expect(rows.map(&:boost_type)).to eq(["critical"])
    end

    it "suppresses every row with *" do
      expect(compile(version("Unknown Edge"), text, view: curation.new(suppressed: ["*"])).rows).to be_empty
    end

    it "never gives a curated boost type a derived twin" do
      rows = compile(version("Unknown Edge"), text, view: curation.new(curated: ["critical"])).rows
      expect(rows.map(&:boost_type)).to eq(["atk"])
    end
  end

  describe "family backfill" do
    it "takes the family from the skill name when the version has none" do
      result = compile(version("Hoarfrost's Tyranny"), "Big boost to ATK")
      expect(result.version.skill_modifier).to eq("Tyranny")
      expect(result.version.skill_size).to eq("big")
      expect(result.rows).to be_empty # Tyranny's own atk/big curve now covers it
    end

    it "leaves a pinned modifier alone" do
      result = compile(version("Hoarfrost's Tyranny"), "Big boost to ATK", view: curation.new(pinned: true))
      expect(result.version.skill_modifier).to be_nil
      expect(result.rows.first.attributes).to include(sl15: 20.0)
    end
  end

  describe "effects" do
    it "writes flat, conditional and supplemental clauses as effects" do
      rows = compile(version("Unknown Edge"), "10% boost to critical hit rate and 100,000 boost to DMG supplement").rows
      expect(rows.map { |r| [r.kind, r.boost_type, r.attributes[:value_unit]] })
        .to include([:effect, "critical", "percent"])
      expect(rows.map(&:attributes)).to all(include(scaling_kind: "static", stacking: "additive",
                                                    applies_to: "element_allies", condition: {}))
    end
  end

  describe "duplicate clauses" do
    # Lovers-Death's Demise (Pain of Death): the knock-out proc's "ATK Boosted" status
    # parses as a second massive ATK clause. Today the second create! failed validation
    # ("Modifier has already been taken"); the compiler keeps the first and warns.
    let(:text) do
      "When main weapon: Massive boost to Dark allies' {{tt|ATK|'''Modifier:''' EX}}. All Dark allies gain " \
        "{{status|ATK Boosted (Stackable/Can't be removed)|a=15%|am=45%|t=Indefinite|m=us}} and " \
        "{{status|DEF Boosted (Stackable / Unremovable)|a=15%|am=45%|t=Indefinite}} when an ally is knocked out."
    end
    let(:reg) { registry_class.new(data: data + [curve_row("Might", "atk", "massive", 22.0, series: "ex")], effects: []) }

    it "produces one row per identity" do
      result = compile(version("Lovers-Death's Demise", series: "ex"), text, reg: reg)
      expect(result.rows.map { |r| [r.kind, r.boost_type] }).to eq([[:datum, "atk"]])
      expect(result.warnings).to include(a_string_matching(/datum atk .* duplicates/))
      WeaponSkills::BuildResult.new(weapon_granblue_id: "1040000000", rows: result.rows).validate!
    end
  end

  describe "Gameplay Notes" do
    let(:voltage_notes) do
      described_class::GameplayNotes.parse(<<~WIKI)
        == Gameplay Notes ==
        === Axe Voltage II ===
        * Multiplier: EX
        * 8% boost to ATK (Max: 80%) for each [[Axe|Axe]] weapon in the grid, per Axe weapon.
      WIKI
    end

    it "writes a per-weapon-count effect for a Voltage weapon" do
      rows = compile(version("Axe Voltage II", modifier: "Voltage"), "", notes: voltage_notes).rows
      expect(rows.size).to eq(1)
      expect(rows.first.attributes).to include(
        modifier: "Axe Voltage II", boost_type: "ex_atk_sp", series: "ex", scaling_kind: "per_grid_count",
        value: 8.0, total_cap: 80.0, count_basis: "same_weapon_type", value_unit: "percent",
        depends_on: ["grid_count"], applies_to: "element_allies"
      )
    end

    it "reads who the boost reaches from the notes (Colomba's Bow Voltage: allies of any element)" do
      notes = described_class::GameplayNotes.parse(<<~WIKI)
        == Gameplay Notes ==
        === Bow Voltage ===
        * Multiplier: EX
        * 4% boost to ATK (Max: 80%) for all allies per [[Weapon Lists/Bow|Bow weapon]] in the grid.
        ** Bow weapons of any element contribute to the boost.
        ** Affects allies of any element.
      WIKI
      rows = compile(version("Bow Voltage", modifier: "Voltage"), "", notes: notes).rows
      expect(rows.map(&:attributes)).to contain_exactly(
        include(boost_type: "ex_atk_sp", scaling_kind: "per_grid_count", value: 4.0, total_cap: 80.0,
                applies_to: "all_allies", depends_on: ["grid_count"])
      )
    end

    it "skips a notes boost type that is curated or suppressed on the version" do
      v = version("Axe Voltage II", modifier: "Voltage")
      expect(compile(v, "", notes: voltage_notes, view: curation.new(curated: ["ex_atk_sp"])).rows).to be_empty
      expect(compile(v, "", notes: voltage_notes, view: curation.new(suppressed: ["ex_atk_sp"])).rows).to be_empty
    end

    it "leaves canonically modeled families (Grand Epic) to their canonical effect" do
      notes = { "Grand Epic" => { frame: "ex", clauses: [{ boost_type: "atk", scaling: :per_count, value: 4.0, max: 80.0 }] } }
      expect(compile(version("Grand Epic", modifier: "Grand Epic"), "", notes: notes).rows).to be_empty
    end

    it "writes nothing for a version whose name has no notes section" do
      expect(compile(version("Dagger Voltage II"), "", notes: voltage_notes).rows).to be_empty
    end

    it "writes a per-specialty table (Celestial) as one specialty_scaled effect" do
      notes = described_class::GameplayNotes.parse(<<~WIKI)
        == Gameplay Notes ==
        === Celestial Ascendancy ===
        * Multiplier: Normal
        {| class="wikitable"
        ! Specialty !! <span data-label="ATK"></span>
        |-
        | Gun || 40%
        |-
        | Other || 20%
        |}
      WIKI
      rows = compile(version("Celestial Ascendancy"), "", notes: notes).rows
      expect(rows.map(&:attributes)).to contain_exactly(
        include(scaling_kind: "specialty_scaled", boost_type: "atk", series: "normal",
                condition: { "specialties" => { "gun" => 40.0, "other" => 20.0 } })
      )
    end

    it "drops a notes static row when the description pass runs (its purge removes it today)" do
      notes = { "Unknown Edge" => { frame: "ex", clauses: [{ boost_type: "hp", scaling: :flat, value: 5.0 }] } }
      expect(compile(version("Unknown Edge"), "", notes: notes).rows.size).to eq(1)
      expect(compile(version("Unknown Edge"), "Big boost to ATK", notes: notes).rows.map(&:boost_type)).to eq(["atk"])
    end
  end

  describe "order independence" do
    let(:texts) do
      ["Big boost to ATK", "Medium boost to ATK based on how high HP is", "10% boost to critical hit rate",
       "Big boost to critical hit rate"]
    end

    it "compiles the same rows from a shuffled registry" do
      versions = [version("Hoarfrost's Tyranny", modifier: "Tyranny", size: "small"), version("Unknown Edge"),
                  version("Whirlwind's Verve", modifier: "Verve")]
      expected = versions.product(texts).map { |v, t| compile(v, t).rows }
      5.times do |seed|
        rng = Random.new(seed)
        shuffled = registry_class.new(data: data.shuffle(random: rng), effects: effects.shuffle(random: rng))
        expect(versions.product(texts).map { |v, t| compile(v, t, reg: shuffled).rows }).to eq(expected)
      end
    end

    it "breaks for_skill ties on the row's values" do
      tied = [curve_row("Fam", "atk", "big", 10.0, sl1: 1.0), curve_row("Fam", "atk", "big", 10.0, sl1: 2.0)]
      picks = Array.new(4) do |seed|
        registry_class.new(data: tied.shuffle(random: Random.new(seed)), effects: [])
                      .for_skill(modifier: "Fam", series: "normal", size: "big").first.sl1
      end
      expect(picks.uniq).to eq([2.0])
    end
  end
end
