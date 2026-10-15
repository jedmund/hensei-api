# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::CurationSnapshot do
  let(:root) { Pathname.new(Dir.mktmpdir("curation_snapshot_spec")) }
  let(:dir) { root.join("weapon_skill_curation") }
  let(:legacy) { root.join("weapon_skill_curation.json") }
  let(:files) { { dir: dir, legacy_path: legacy } }
  let(:series) { create(:weapon_series, slug: "spec-series") }
  let(:weapon) { create(:weapon, weapon_series: series) }
  let(:weapon_skill) { create(:weapon_skill, weapon: weapon) }
  let(:version) { create(:weapon_skill_version, weapon_skill: weapon_skill) }
  let(:edited_at) { Time.utc(2026, 7, 6, 12) }
  let(:quiet) { StringIO.new }

  after { FileUtils.rm_rf(root) }

  def curate_effect(attrs = {})
    WeaponSkillEffect.create!({ weapon_skill_version: version, modifier: "Axe Voltage II", boost_type: "ex_atk_sp",
                                series: "ex", scaling_kind: "per_grid_count", value: 8, condition: {},
                                manually_edited_at: edited_at, provenance: "manual" }.merge(attrs))
  end

  def ref(target = version)
    { "weapon" => target.weapon_skill.weapon_granblue_id, "skill" => target.skill.name_en, "ordinal" => target.ordinal }
  end

  def write_overlay(name, sections, at = dir)
    FileUtils.mkdir_p(at)
    File.write(at.join(name), JSON.generate({ "format" => 2 }.merge(sections)))
  end

  def op(kind, attrs = {})
    { "op" => kind }.merge(ref).merge("reason" => "gbf.wiki spec", "edited_at" => edited_at.iso8601).merge(attrs)
  end

  def sync = described_class.sync(**files, log: quiet)

  describe "rows and overrides" do
    it "restores curated rows from the overlay and is idempotent" do
      curate_effect
      WeaponSkillDatum.create!(weapon_skill_version: version, modifier: "Draconic Progression", boost_type: "atk",
                               series: "ex", formula_type: "progression", sl20: 2.0, max_value: 25,
                               manually_edited_at: edited_at, provenance: "manual")
      version.update!(suppressed_boosts: ["e_atk_prog"], overrides_edited_at: edited_at)
      described_class.export(**files)

      WeaponSkillEffect.delete_all
      WeaponSkillDatum.delete_all
      version.update!(suppressed_boosts: [], overrides_edited_at: nil)

      first = sync
      expect([first.created, first.updated, first.unmatched]).to eq([2, 1, []])
      expect(WeaponSkillEffect.sole).to have_attributes(weapon_skill_version_id: version.id, value: 8,
                                                        manually_edited_at: edited_at)
      expect(WeaponSkillDatum.sole).to have_attributes(sl20: 2.0, max_value: 25)
      expect(version.reload.suppressed_boosts).to eq(["e_atk_prog"])

      second = sync
      expect([second.created, second.updated, second.changed?]).to eq([0, 0, false])
    end

    it "keeps a row that was edited after the export" do
      effect = curate_effect
      described_class.export(**files)
      effect.update!(value: 10, manually_edited_at: edited_at + 1.day) # e.g. a later admin-editor edit

      sync

      expect(effect.reload.value).to eq(10)
    end

    it "overwrites a generated row with the curated one" do
      effect = curate_effect
      described_class.export(**files)
      effect.update!(value: 4, manually_edited_at: nil, provenance: nil) # a reparse regenerated it

      sync

      expect(effect.reload).to have_attributes(value: 8, manually_edited_at: edited_at)
    end

    it "removes uncurated rows of a suppressed boost type" do
      version.update!(suppressed_boosts: ["dmg_cap"], overrides_edited_at: edited_at)
      described_class.export(**files)
      WeaponSkillEffect.create!(weapon_skill_version: version, modifier: "Astral Claw", boost_type: "dmg_cap",
                                scaling_kind: "static", value: 10, condition: {})

      report = sync

      expect(report.suppressed).to eq(1)
      expect(WeaponSkillEffect.where(boost_type: "dmg_cap")).to be_empty
    end

    it "applies overrides to a version whose derived modifier isn't in the model's list" do
      version.update!(suppressed_boosts: ["e_atk"], overrides_edited_at: edited_at)
      described_class.export(**files)
      version.update_columns(skill_modifier: "Star-Sea Sovereign's Decree", suppressed_boosts: [], overrides_edited_at: nil)

      expect { sync }.not_to raise_error
      expect(version.reload.suppressed_boosts).to eq(["e_atk"])
    end

    it "reports a row that no longer matches a skill instead of guessing" do
      curate_effect
      described_class.export(**files)
      version.skill.update!(name_en: "Renamed Skill")

      report = sync

      expect(report.unmatched.size).to eq(1)
      expect(WeaponSkillEffect.where(weapon_skill_version_id: nil)).to be_empty
    end

    it "exports a stamped version with every override cleared" do
      version.update!(overrides_edited_at: edited_at)
      described_class.export(**files)
      version.update!(series_override: "omega", overrides_edited_at: nil)

      sync

      expect(version.reload).to have_attributes(series_override: nil, overrides_edited_at: edited_at)
    end
  end

  describe "files" do
    it "validates the committed overlay and any pending fragments" do
      expect { described_class.load }.not_to raise_error
      expect { described_class::Overlay.load(dir: described_class::PENDING_DIR) }.not_to raise_error
    end

    it "files entries by series, canonical rows apart, sorted, and keeps ops" do
      curate_effect
      curate_effect(weapon_skill_version: nil, modifier: "α Pendulum", boost_type: "ca_dmg_cap", key_slug: "pendulum-alpha")
      loose = create(:weapon_skill_version, weapon_skill: create(:weapon_skill, weapon: create(:weapon, weapon_series: nil)))
      loose.update!(size_override: "big", overrides_edited_at: edited_at)
      write_overlay("old-name.json", "ops" => [op("gate", "unlock_level" => 150)])

      described_class.export(**files)

      expect(Dir.children(dir).sort).to eq(%w[_canonical.json _none.json spec-series.json])
      doc = JSON.parse(File.read(dir.join("spec-series.json")))
      expect(doc.keys).to eq(%w[format versions effects data ops])
      expect(doc["effects"].map { |e| e["modifier"] }).to eq(["Axe Voltage II"])
      expect(doc["ops"].sole).to include("op" => "gate", "unlock_level" => 150)
      expect(JSON.parse(File.read(dir.join("_canonical.json")))["effects"].sole).not_to have_key("weapon")
      expect(JSON.parse(File.read(dir.join("_none.json")))["versions"].sole).to include("size_override" => "big")
    end

    it "reads the v1 file alongside v2 files and the export replaces it" do
      curate_effect
      described_class.export(**files)
      v1 = JSON.parse(File.read(dir.join("spec-series.json"))).slice("effects")
      FileUtils.rm_rf(dir)
      File.write(legacy, JSON.generate(v1))
      WeaponSkillEffect.delete_all

      expect(sync.created).to eq(1)

      described_class.export(**files)
      expect(File.exist?(legacy)).to be(false)
      expect(described_class.drift(**files).values).to all(be_empty)
    end

    it "aborts before writing anything when a file is invalid" do
      curate_effect
      described_class.export(**files)
      WeaponSkillEffect.delete_all
      write_overlay("broken.json", "ops" => [op("gate")]) # a gate with no fields

      expect { sync }.to raise_error(described_class::Overlay::Invalid, /broken\.json: ops\[0\]: gate needs/)
      expect(WeaponSkillEffect.count).to eq(0)
    end

    it "rejects unparseable JSON with the file name" do
      FileUtils.mkdir_p(dir)
      File.write(dir.join("bad.json"), "{")

      expect { sync }.to raise_error(described_class::Overlay::Invalid, /bad\.json: not valid JSON/)
    end

    it "rejects the same identity in two files" do
      write_overlay("a.json", "ops" => [op("gate", "unlock_level" => 150)])
      write_overlay("b.json", "ops" => [op("gate", "unlock_level" => 200)])

      expect { sync }.to raise_error(described_class::Overlay::Invalid, /b\.json ops\[0\]: same identity as .*a\.json ops\[0\]/)
    end
  end

  describe "structural ops" do
    it "gates a version once" do
      write_overlay("s.json", "ops" => [op("gate", "unlock_level" => 200, "min_uncap" => 5, "transcendence_stage" => 0)])

      expect(sync).to have_attributes(ops_applied: 1, ops_satisfied: 0)
      expect(version.reload).to have_attributes(unlock_level: 200, min_uncap: 5)
      expect(sync).to have_attributes(ops_applied: 0, ops_satisfied: 1, unmatched: [])
    end

    it "removes a version with its rows, and its slot when that was the last tier" do
      curate_effect
      write_overlay("s.json", "ops" => [op("remove_version")])

      expect(sync.ops_applied).to eq(1)
      expect(WeaponSkillVersion.exists?(version.id)).to be(false)
      expect(WeaponSkillEffect.count).to eq(0)
      expect(WeaponSkill.exists?(weapon_skill.id)).to be(false)
    end

    it "treats an already removed version as done, but reports an unknown weapon" do
      create(:weapon_skill, weapon: weapon) # the weapon still has slots
      write_overlay("s.json", "ops" => [op("remove_version", "skill" => "Long Gone"),
                                        op("remove_version", "weapon" => "1999999999")])

      report = sync

      expect(report.ops_satisfied).to eq(1)
      expect(report.unmatched.map { |e| e["weapon"] }).to eq(["1999999999"])
    end

    it "adds a missing version and applies overrides on top of it, once" do
      added = { "weapon" => weapon.granblue_id, "skill" => "Water's Majesty", "ordinal" => 0 }
      write_overlay("s.json",
                    "ops" => [op("add_version", added.merge("position" => 4, "skill_jp" => "水の威光", "unlock_level" => 120,
                                                            "min_uncap" => 4, "transcendence_stage" => 0))],
                    "versions" => [added.merge("modifier_override" => "Majesty", "series_override" => "normal",
                                               "size_override" => "small", "edited_at" => edited_at.iso8601)])

      expect(sync).to have_attributes(ops_applied: 1, updated: 1, unmatched: [])
      created = described_class.find_version(added)
      expect(created).to have_attributes(unlock_level: 120, min_uncap: 4, resolved_modifier: "Majesty",
                                         resolved_series: "normal", resolved_size: "small")
      expect(created.weapon_skill).to have_attributes(weapon_granblue_id: weapon.granblue_id, position: 4)
      expect(created.skill).to have_attributes(name_jp: "水の威光", skill_type: "weapon")

      expect(sync).to have_attributes(ops_applied: 0, ops_satisfied: 1, updated: 0, changed?: false)
    end

    it "won't add a version over another skill's tier" do
      taken = { "weapon" => weapon.granblue_id, "skill" => "Interloper", "ordinal" => version.ordinal,
                "position" => weapon_skill.position, "min_uncap" => 3 }
      write_overlay("s.json", "ops" => [op("add_version", taken)])

      expect(sync.unmatched.size).to eq(1)
    end

    it "applies remove_version before add_version whatever the file order" do
      replacement = { "weapon" => weapon.granblue_id, "skill" => "Replacement", "ordinal" => version.ordinal,
                      "position" => weapon_skill.position, "min_uncap" => 3 }
      write_overlay("s.json", "ops" => [op("add_version", replacement), op("remove_version")])

      expect(sync).to have_attributes(ops_applied: 2, unmatched: [])
      expect(described_class.find_version(replacement)).to be_present
    end

    context "with the per-version text columns" do
      # Until W6c's migration lands, add the columns inside a savepoint (Postgres DDL is
      # transactional) and drop them again before the column cache is reset.
      around do |example|
        connection = ActiveRecord::Base.connection
        connection.transaction(requires_new: true) do
          %i[description_en description_jp].each do |column|
            connection.add_column(:weapon_skill_versions, column, :text) unless connection.column_exists?(:weapon_skill_versions, column)
          end
          WeaponSkillVersion.reset_column_information
          example.run
          raise ActiveRecord::Rollback
        end
      ensure
        WeaponSkillVersion.reset_column_information
      end

      it "sets the version's text once" do
        write_overlay("s.json", "ops" => [op("description", "description_en" => "Big boost to ATK")])

        expect(sync.ops_applied).to eq(1)
        expect(version.reload.read_attribute(:description_en)).to eq("Big boost to ATK")
        expect(sync).to have_attributes(ops_applied: 0, ops_satisfied: 1)
      end
    end

    context "without the per-version text columns" do
      before { allow(described_class::Ops).to receive(:description_columns?).and_return(false) }

      it "waits instead of failing" do
        write_overlay("s.json", "ops" => [op("description", "description_en" => "Big boost to ATK")])

        expect(sync).to have_attributes(ops_applied: 0, ops_skipped: 1, unmatched: [])
        expect(described_class.drift(**files)["unapplied"]).to be_empty
      end
    end
  end

  describe ".drift" do
    it "flags curation that hasn't been exported" do
      described_class.export(**files)
      curate_effect

      drift = described_class.drift(**files)

      expect(drift["missing"].map { |row| row["modifier"] }).to eq(["Axe Voltage II"])
      expect(drift["changed"]).to be_empty
    end

    it "lists ops this database doesn't reflect" do
      write_overlay("s.json", "ops" => [op("gate", "unlock_level" => 200)])

      expect(described_class.drift(**files)["unapplied"].map { |e| e["op"] }).to eq(["gate"])
      sync
      expect(described_class.drift(**files)["unapplied"]).to be_empty
    end
  end

  describe ".split" do
    let(:pending) { dir.join("pending") }

    it "moves v1 and pending fragments into series files, newer stamps winning" do
      curate_effect
      described_class.export(**files)
      File.write(legacy, JSON.generate(JSON.parse(File.read(dir.join("spec-series.json"))).slice("effects")))
      FileUtils.rm_f(dir.join("spec-series.json"))
      write_overlay("old.json", "ops" => [op("gate", "unlock_level" => 150)])
      write_overlay("spec-series.json",
                    { "ops" => [op("gate", "unlock_level" => 150), # identical: collapses
                                op("remove_version", "edited_at" => (edited_at + 1.day).iso8601, "skill" => "Other")] },
                    pending)

      counts = described_class.split(dir: dir, legacy_path: legacy, pending_dir: pending, log: quiet)

      expect(counts).to eq("spec-series.json" => 3)
      expect(File.exist?(legacy)).to be(false)
      expect(Dir.children(pending)).to be_empty
      expect(described_class.load(**files).entries("ops").map { |e| e["op"] }).to match_array(%w[gate remove_version])
    end

    it "lets a newer fragment replace an entry with the same identity, and says so" do
      write_overlay("x.json", "ops" => [op("gate", "unlock_level" => 150)])
      write_overlay("x.json", { "ops" => [op("gate", "unlock_level" => 200, "edited_at" => (edited_at + 1.day).iso8601)] },
                    pending)

      described_class.split(dir: dir, legacy_path: legacy, pending_dir: pending, log: quiet)

      expect(described_class.load(**files).entries("ops").sole["unlock_level"]).to eq(200)
      expect(quiet.string).to match(/gate .*kept .*"unlock_level":200.*dropped .*"unlock_level":150/)
    end

    it "keeps the newer entry over an older fragment" do
      write_overlay("x.json", "ops" => [op("gate", "unlock_level" => 150)])
      write_overlay("x.json", { "ops" => [op("gate", "unlock_level" => 200, "edited_at" => (edited_at - 1.day).iso8601)] },
                    pending)

      described_class.split(dir: dir, legacy_path: legacy, pending_dir: pending, log: quiet)

      expect(described_class.load(**files).entries("ops").sole["unlock_level"]).to eq(150)
      expect(quiet.string).to include("dropped")
    end
  end

  describe ".view" do
    it "answers what the overlay curates or suppresses on a version" do
      curate_effect
      version.update!(modifier_override: "none", suppressed_boosts: ["dmg_cap"], overrides_edited_at: edited_at)
      described_class.export(**files)
      built = WeaponSkills::BuildResult::Version.new(weapon_granblue_id: weapon.granblue_id, position: weapon_skill.position,
                                                     ordinal: version.ordinal, skill_name_en: version.skill.name_en)
      other = built.dup.tap { |v| v.skill_name_en = "Other" }

      view = described_class.view(**files)

      expect(view.curated_boost_types(built)).to eq(Set["ex_atk_sp"])
      expect(view.suppressed(built)).to eq(Set["dmg_cap"])
      expect(view.modifier_pinned?(built)).to be(true)
      expect([view.curated_boost_types(other), view.suppressed(other), view.modifier_pinned?(other)]).to eq([Set[], Set[], false])
      expect(view.suppressed(built)).to be_frozen
    end
  end
end
