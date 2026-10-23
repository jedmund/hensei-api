# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::Build::Runner do
  let(:io) { StringIO.new }
  let(:series) { create(:weapon_series, slug: "spec-series") }
  let!(:sourced) { create(:weapon, granblue_id: "1040000001", weapon_series: series) }
  let!(:slotted) { create(:weapon, granblue_id: "1040000002") }
  let!(:outside) { create(:weapon, granblue_id: "1040000003") }
  let(:context) do
    WeaponSkills::Build::Context.new(store: WeaponSkills::SourceStore::Memory.new,
                                     overlay: Granblue::CurationSnapshot::Overlay.new([]))
  end
  let(:report) { WeaponSkills::Build::Writer::Report.zero.tap { |r| r.rows_created = 2 } }

  before do
    WeaponSource.create!(weapon: sourced, kind: "wiki_raw", key: "Sourced", body: "page", fetched_at: Time.current)
    WeaponSkill.create!(weapon_granblue_id: slotted.granblue_id, position: 1)
    allow(WeaponSkills::Build).to receive(:for) do |weapon, **|
      built_granblue_ids << weapon.granblue_id
      WeaponSkills::BuildResult.new(weapon_granblue_id: weapon.granblue_id, warnings: ["w"])
    end
    allow(WeaponSkills::Build::Writer).to receive(:call).and_return(report)
    allow(Granblue::CurationSnapshot).to receive(:sync)
    allow(Granblue::Extractors::KeySkillExtractor).to receive(:run).and_return([{}, []])
    allow(WeaponSkills::ParitySnapshot).to receive(:write)
  end

  def run(mode: "write", **)
    described_class.new(mode: mode, io: io, context: context, **).call
  end

  def built_granblue_ids = (@built_granblue_ids ||= [])

  describe "scope" do
    it "covers weapons with a stored wiki_raw source or existing slots" do
      expect(run.built).to eq(2)
      expect(built_granblue_ids).to eq(%w[1040000001 1040000002])
    end

    it "narrows to ids=" do
      run(ids: %w[1040000002 1040000003])
      expect(built_granblue_ids).to eq(%w[1040000002])
      expect(io.string).to include("Not in scope (no stored wiki_raw source or slots): 1040000003")
    end

    it "narrows to series=" do
      run(series: %w[spec-series])
      expect(built_granblue_ids).to eq(%w[1040000001])
    end
  end

  describe "staleness" do
    it "stores the fingerprint after a write and skips the weapon until it changes" do
      run
      expect(sourced.reload.weapon_skill_build_fingerprint).to match(/\A\h{64}\z/)
      expect(sourced.weapon_skill_built_at).to be_present

      expect(run.built).to eq(0)
      WeaponSource.find_by(weapon: sourced).update!(body: "edited page")
      summary = run
      expect(summary.built).to eq(1)
      expect(summary.stale).to eq(1)
    end

    it "builds every weapon in scope with all=true" do
      run
      expect(run(all: true).built).to eq(2)
    end

    it "builds every stale weapon when VERSION is bumped" do
      run
      stub_const("WeaponSkills::Build::VERSION", WeaponSkills::Build::VERSION + 1)
      expect(run.built).to eq(2)
    end
  end

  describe "write" do
    it "sums the writer reports, counts warnings, then syncs the overlay and extracts keys once" do
      summary = run
      expect(summary.counts.rows_created).to eq(4)
      expect(summary.warnings).to eq(2)
      expect(Granblue::CurationSnapshot).to have_received(:sync).once
      expect(Granblue::Extractors::KeySkillExtractor).to have_received(:run).with(store: context.store).once
      expect(io.string).to include("build_weapon_skills (write): 2 in scope, 2 stale, 2 built, 0 failed")
    end

    it "counts the rows copied from a fallback curve" do
      fallback = WeaponSkills::BuildResult::Row.new(
        version_identity: ["1040000001", 0, 0], kind: :datum, boost_type: "atk", condition: nil,
        attributes: { boost_type: "atk", provenance: "fallback:Might/ex" }
      )
      own = WeaponSkills::BuildResult::Row.new(version_identity: ["1040000001", 0, 0], kind: :datum,
                                               boost_type: "hp", condition: nil, attributes: { boost_type: "hp" })
      allow(WeaponSkills::Build).to receive(:for) do |weapon, **|
        WeaponSkills::BuildResult.new(weapon_granblue_id: weapon.granblue_id, rows: [fallback, own])
      end

      expect(run.fallback_rows).to eq(2)
      expect(io.string).to include("2 fallback rows")
    end

    it "logs a weapon that fails, doesn't store its fingerprint, and carries on" do
      allow(WeaponSkills::Build).to receive(:for).and_call_original
      allow(WeaponSkills::Build).to receive(:for).with(sourced, context: context).and_raise("bad page")
      allow(WeaponSkills::Build).to receive(:for).with(slotted, context: context)
                                                 .and_return(WeaponSkills::BuildResult.new(weapon_granblue_id: "1040000002"))

      summary = run
      expect(summary.failed).to eq(1)
      expect(summary.built).to eq(1)
      expect(io.string).to include("1040000001 #{sourced.name_en}: RuntimeError: bad page")
      expect(sourced.reload.weapon_skill_build_fingerprint).to be_nil
      expect(slotted.reload.weapon_skill_build_fingerprint).to be_present
    end

    it "skips the sync and keys when nothing was built" do
      run
      run
      expect(Granblue::CurationSnapshot).to have_received(:sync).once
    end
  end

  describe "shadow" do
    it "rolls everything back and prints the diff by series" do
      allow(WeaponSkills::Build::Writer).to receive(:call) do
        WeaponSkill.create!(weapon_granblue_id: sourced.granblue_id, position: 9)
        report
      end
      diff = { "changed" => [], "missing" => [], "added" => ["1040000001|9|0|Might"], "keys" => [] }
      allow(WeaponSkills::ParitySnapshot).to receive_messages(capture: {}, diff: diff)

      expect { run(mode: "shadow") }.not_to change(WeaponSkill, :count)
      expect(sourced.reload.weapon_skill_build_fingerprint).to be_nil
      expect(WeaponSkills::ParitySnapshot).to have_received(:write).with(diff, WeaponSkills::ParitySnapshot::LAST_DIFF_PATH)
      expect(io.string).to include("== spec-series", "  + 1040000001|9|0|Might", "build_weapon_skills (shadow)")
    end

    it "shows only the first diff_limit differences" do
      diff = { "changed" => [], "missing" => [], "keys" => [],
               "added" => (1..5).map { |n| "1040000001|#{n}|0|Might" } }
      allow(WeaponSkills::ParitySnapshot).to receive_messages(capture: {}, diff: diff)

      run(mode: "shadow", diff_limit: 2)
      expect(io.string.scan(/^  \+ /).size).to eq(2)
      expect(io.string).to include("… 3 more differences not shown")
    end

    it "keeps the transaction usable when one weapon's write fails" do
      allow(WeaponSkills::ParitySnapshot).to receive_messages(capture: {}, diff: WeaponSkills::ParitySnapshot.diff(
        { "meta" => {}, "versions" => {} }, { "meta" => {}, "versions" => {} }
      ))
      allow(WeaponSkills::Build::Writer).to receive(:call) do |result, **|
        raise ActiveRecord::StatementInvalid, "boom" if result.weapon_granblue_id == "1040000001"

        WeaponSkill.count # a query after the failure: the savepoint kept the transaction alive
        report
      end

      summary = run(mode: "shadow")
      expect(summary.failed).to eq(1)
      expect(summary.built).to eq(1)
    end
  end

  describe ".deploy" do
    it "does nothing when the build is off" do
      expect(described_class.deploy(mode: "off", io: io)).to be_nil
      expect(WeaponSkills::Build).not_to have_received(:for)
    end

    it "never raises in shadow mode" do
      allow(WeaponSkills::Build).to receive(:context).and_raise(ActiveRecord::StatementInvalid, "broken")

      expect { described_class.deploy(mode: "shadow", io: io) }.not_to raise_error
      expect(io.string).to include("build_weapon_skills (shadow) failed; the deploy continues: " \
                                   "ActiveRecord::StatementInvalid: broken")
    end

    it "builds stale weapons in write mode and reports, without raising, when one failed" do
      allow(WeaponSkills::Build).to receive_messages(context: context)
      expect(described_class.deploy(mode: "write", io: io).built).to eq(2)

      WeaponSource.find_by(weapon: sourced).update!(body: "edited")
      allow(WeaponSkills::Build).to receive(:for).and_raise("bad page")
      expect { described_class.deploy(mode: "write", io: io) }.not_to raise_error
      expect(io.string).to include("1 weapons failed and kept their existing rows")
    end
  end
end
