# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

# Fixtures are stored wiki sources exported from catalogue-20261015-sources (expansions
# trimmed to their weapon-skills table); the expectations are today's database rows.
RSpec.describe WeaponSkills::Build::Structure do
  def fixture(granblue_id)
    JSON.parse(Rails.root.join("spec/fixtures/weapon_sources/#{granblue_id}.json").read)
  end

  def store_for(doc, order: nil)
    store = WeaponSkills::SourceStore::Memory.new
    sources = doc["sources"]
    sources = sources.shuffle(random: Random.new(order)) if order
    sources.each { |s| store.put(s["kind"], s["key"], s["body"], page_kind: s["page_kind"]) }
    store
  end

  def compile(granblue_id, order: nil, store: nil)
    doc = fixture(granblue_id)
    weapon = Weapon.new(**doc["weapon"].symbolize_keys)
    described_class.call(weapon, store: store || store_for(doc, order: order))
  end

  def versions(granblue_id, **)
    compile(granblue_id, **)[1].to_h { |v| [[v.position, v.ordinal], v] }
  end

  def gate(version) = [version.unlock_level, version.min_uncap, version.transcendence_stage]

  before { WebMock.disable_net_connect! }
  after { WebMock.allow_net_connect! }

  describe "inline page (Illustrious: Murcielago)" do
    subject(:result) { versions("1040711700") }

    it "parses every slot and tier from the page" do
      expect(result.values.map(&:skill_name_en)).to eq(
        ["Sangre Caliente", "Sangre Caliente II", "Robar Tiempo", "Robar Tiempo II",
         "Lluvia de Saetas", "Lluvia de Saetas II", "Dos Colmillos", "Dos Colmillos II"]
      )
    end

    it "applies the template's s4_lvl default (P2) and its s4_4s_lvl to the u1 tier (P1)" do
      expect(gate(result[[3, 0]])).to eq([230, 5, 3])
      expect(gate(result[[3, 1]])).to eq([250, 5, 5])
      expect(result[[3, 1]].skill_name_en).to eq("Dos Colmillos II")
    end

    it "keeps the page's own u1 levels" do
      expect(gate(result[[0, 1]])).to eq([210, 5, 1])
    end

    it "carries each tier's own text" do
      expect(result[[3, 1]].description_en).to start_with("When main weapon (MC only): Damage skills and debuff skills")
    end
  end

  describe "inline page with template-garbled names (New World: Rise of Justice)" do
    subject(:result) { versions("1040020800") }

    it "drops the garbled tiers and appends the expansion's skills after the last slot" do
      expect(result.keys).to eq([[0, 0], [0, 1], [3, 0], [4, 0]])
      expect(result[[3, 0]].skill_name_en).to eq("Sephira Maxi-Water")
      expect(result[[4, 0]].skill_name_en).to eq("Water's Majesty")
    end

    it "gives the injected Majesty the gate of the template tier it fills in (P3)" do
      expect(gate(result[[4, 0]])).to eq([120, 4, 0])
    end

    it "keeps the template's literal icon over the page's, as the old merge did" do
      expect(result[[0, 0]].icon).to eq("{{WeaponSkillIcon|ws_skill_evoker_*.png}}")
    end
  end

  describe "series-template page (Exo Heliocentrum)" do
    subject(:result) { versions("1040424300") }

    it "builds the skills from the expansion" do
      expect(result.transform_values(&:skill_name_en)).to eq(
        [1, 0] => "Resplendent Ruler's Jurisdiction",
        [2, 0] => "Solaris's Supremacy",
        [3, 0] => "Solaris's Supremacy: Decimation"
      )
    end

    it "gates Decimation by the template's {{#if: 5star_date | 200}} (P6)" do
      expect(gate(result[[3, 0]])).to eq([200, 5, 0])
    end
  end

  describe "Celestial page (template routing)" do
    subject(:result) { versions("1040517100") }

    it "routes through Template:Weapon/Common/Celestial and its expansion" do
      expect(result.transform_values(&:skill_name_en)).to eq(
        [1, 0] => "Cloud of Howling Twilight",
        [2, 0] => "Guiding Star's Splendor",
        [3, 0] => "Gun Voltage II",
        [4, 0] => "Cloud of Howling Twilight II"
      )
    end

    it "reads levels and frames from the template and the expansion" do
      expect(gate(result[[2, 0]])).to eq([150, 4, 0])
      expect(gate(result[[4, 0]])).to eq([200, 5, 0])
      expect(result[[2, 0]].multiplier_frame).to eq("normal")
    end

    # The template's ens3_desc is a summary without numbers ("Boost to ATK, DEF, and max
    # HP"); the row compiler falls back to this text, so it must be the expansion's.
    it "takes the expansion's text before the template's summary, as VersionText::Backfill does" do
      expect(result[[2, 0]].description_en)
        .to eq("30% boost to ATK , 25% boost to DEF, and 30% boost to max HP for all allies.")
      expect(result[[1, 0]].description_en).not_to include("{{{weapon")
    end
  end

  describe "Epic page (Chains of Caucasus)" do
    it "evaluates the template's #ifeq on the release date (P2)" do
      expect(gate(versions("1040018900")[[1, 0]])).to eq([120, 4, 0])
    end
  end

  describe "Proven page (Bident)" do
    it "appends the Armed skill, which the template names through a placeholder" do
      result = versions("1040213800")

      expect(result.transform_values(&:skill_name_en)).to eq([1, 0] => "Abyssal Avenger", [2, 0] => "Armed Flood")
      expect(gate(result[[1, 0]])).to eq([120, 4, 0])
    end
  end

  describe "key-determined pages" do
    it "keeps a Dark Opus page's base tiers and never turns pendulum options into versions" do
      result = versions("1040017100")

      expect(result.transform_values(&:skill_name_en)).to eq(
        [0, 0] => "Majesty", [0, 1] => "Majesty II", [0, 2] => "Apotheosis",
        [1, 0] => "Guiding Revelation", [2, 0] => "Guiding Gospel"
      )
      expect(gate(result[[0, 2]])).to eq([230, 5, 3])
    end

    it "puts a Draconic page's base skill in place of the garbled tier it renders" do
      result = versions("1040311900")

      expect(result[[0, 0]].skill_name_en).to eq("Wamdus's Flood")
      expect(result[[0, 0]].icon).to eq("ws_skill_job_weapon.png")
      expect(result.keys).to eq([[0, 0], [1, 0], [2, 0]])
    end
  end

  describe "choosing the parser" do
    it "goes by the stored page_kind, not by the text: a |jps1_desc= line doesn't make a page inline" do
      doc = fixture("1040713300") # Gusisnautar (Proven)
      raw = doc["sources"].find { |s| s["kind"] == "wiki_raw" }
      expect(raw["page_kind"]).to eq("series_template")
      expect(raw["body"]).to include("|jps1_desc=")
      expect(raw["body"]).not_to match(/^\|\s*s1_desc\s*=/)

      inline = doc.deep_dup
      inline["sources"].find { |s| s["kind"] == "wiki_raw" }["page_kind"] = "inline"
      weapon = Weapon.new(**doc["weapon"].symbolize_keys)

      as_template = described_class.call(weapon, store: store_for(doc))[1]
      as_inline = described_class.call(weapon, store: store_for(inline))[1]
      expect(as_template.map(&:skill_name_en)).to eq(["Golden Frailty", "Armed Shine"])
      expect(as_inline.map(&:skill_name_en)).to eq(["Golden Frailty"])
    end

    it "warns instead of fetching when a needed source isn't stored" do
      doc = fixture("1040424300")
      doc["sources"].reject! { |s| s["kind"] == "expanded" }
      weapon = Weapon.new(**doc["weapon"].symbolize_keys)

      _slots, versions, warnings = described_class.call(weapon, store: store_for(doc))
      expect(warnings).to include(a_string_including("needs its expansion"))
      expect(versions.map(&:skill_name_en)).to eq(["Resplendent Ruler's Jurisdiction"])
    end
  end

  describe "purity" do
    it "gives the same answer whatever order the sources were stored in" do
      %w[1040711700 1040020800 1040517100 1040311900].each do |gid|
        expected = compile(gid)
        3.times { |seed| expect(compile(gid, order: seed)).to eq(expected) }
      end
    end

    it "makes no HTTP requests" do
      compile("1040020800")
      expect(WebMock).not_to have_requested(:any, /.*/)
    end

    it "returns one slot per occupied position and valid identities" do
      slots, versions, = compile("1040020800")
      result = WeaponSkills::BuildResult.new(weapon_granblue_id: "1040020800", slots: slots, versions: versions)

      expect { result.validate! }.not_to raise_error
      expect(slots.map(&:position)).to eq([0, 3, 4])
    end
  end
end
