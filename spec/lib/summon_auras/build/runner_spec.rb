# frozen_string_literal: true

require "rails_helper"

RSpec.describe SummonAuras::Build::Runner do
  include ActiveJob::TestHelper

  let(:io) { StringIO.new }

  def wiki(main = "50% boost to Water Elemental ATK.", sub: "10% boost to Water allies' HP.")
    <<~WIKI
      {{Summon
      |aura1=#{main}
      |aura2=80% boost to Water Elemental ATK.
      |subaura1=#{sub}
      }}
    WIKI
  end

  def make(granblue_id, raw = wiki, **attrs)
    Summon.without_aura_build { create(:summon, granblue_id: granblue_id, element: 2, wiki_raw: raw, **attrs) }
  end

  def run(mode: "write", **)
    described_class.new(mode: mode, io: io, **).call
  end

  def auras(summon) = SummonAura.where(summon_granblue_id: summon.granblue_id)

  let!(:first) { make("2040900001") }
  let!(:second) { make("2040900002") }

  it "builds every stale summon and stores its fingerprint" do
    summary = run
    expect(summary).to have_attributes(in_scope: 2, stale: 2, built: 2, failed: 0)
    expect(auras(first).pluck(:slot, :uncap_level, :target, :value).sort)
      .to eq([["main", 0, "elemental_atk", 50], ["main", 3, "elemental_atk", 80], ["sub", 0, "other", 10]])
    expect(first.reload.summon_aura_build_fingerprint).to be_present
  end

  it "is idempotent: a second run finds nothing stale and changes nothing" do
    run
    ids = auras(first).order(:id).pluck(:id, :updated_at)
    summary = run
    expect(summary).to have_attributes(stale: 0, built: 0)
    expect(auras(first).order(:id).pluck(:id, :updated_at)).to eq(ids)
  end

  it "rebuilds a summon whose page changed, keeping the ids of the tiers it updates" do
    run
    id = auras(first).find_by(slot: "main", uncap_level: 0).id
    put_source(first, :wiki_raw, wiki("60% boost to Water Elemental ATK.", sub: ""))

    summary = run
    expect(summary).to have_attributes(stale: 1, built: 1)
    expect(summary.counts).to have_attributes(created: 0, updated: 1, deleted: 1)
    expect(auras(first).find_by(slot: "main", uncap_level: 0)).to have_attributes(id: id, value: 60)
    expect(auras(first).where(slot: "sub")).to be_empty
  end

  it "makes a summon stale when its series changes" do
    run
    first.update_columns(summon_series_id: create(:summon_series, slug: "spec-series").id)
    expect(run).to have_attributes(stale: 1)
  end

  it "keeps the existing auras when the page has no aura fields" do
    run
    put_source(first, :wiki_raw, "{{Character\n|name=Not a summon\n}}")
    summary = run
    expect(summary).to have_attributes(empty: 1, built: 0)
    expect(auras(first).count).to eq(3)
    expect(io.string).to include("2040900001 #{first.name_en}: the build made no auras; kept its existing auras")
  end

  it "keeps the existing auras of a summon with no stored page" do
    run
    Source.where(owner_type: "Summon", owner_id: first.id, kind: "wiki_raw").delete_all
    summary = run
    expect(summary).to have_attributes(no_source: 1)
    expect(auras(first).count).to eq(3)
  end

  it "fingerprints a summon with no auras whose build is empty, so it isn't rebuilt" do
    blank = make("2040900003", "{{Summon\n|name=Call only\n}}")
    expect(run(ids: [blank.granblue_id])).to have_attributes(built: 1)
    expect(run(ids: [blank.granblue_id])).to have_attributes(stale: 0)
  end

  it "rolls back in shadow mode and prints the differences" do
    summary = run(mode: "shadow")
    expect(summary.differing).to eq(2)
    expect(SummonAura.count).to eq(0)
    expect(first.reload.summon_aura_build_fingerprint).to be_nil
    expect(io.string).to include("created 2040900001 #{first.name_en} main 0★ t0")
  end

  it "builds only the summons named by ids" do
    expect(run(ids: [second.granblue_id])).to have_attributes(in_scope: 1, built: 1)
    expect(auras(first)).to be_empty
  end

  it "counts a summon that raises, keeps its rows and leaves it stale" do
    run(ids: [first.granblue_id])
    put_source(first, :wiki_raw, wiki("70% boost to Water Elemental ATK."))
    allow(SummonAuras::Build::Writer).to receive(:call).and_raise(ActiveRecord::StatementInvalid, "boom")

    summary = run(ids: [first.granblue_id])
    expect(summary).to have_attributes(failed: 1, built: 0)
    expect(auras(first).find_by(slot: "main", uncap_level: 0).value).to eq(50)
    allow(SummonAuras::Build::Writer).to receive(:call).and_call_original
    expect(run(ids: [first.granblue_id])).to have_attributes(stale: 1, built: 1)
  end

  describe ".deploy" do
    it "does nothing when off" do
      expect(described_class.deploy(mode: "off", io: io)).to be_nil
      expect(SummonAura.count).to eq(0)
    end

    it "never raises in shadow mode" do
      allow_any_instance_of(described_class).to receive(:scope).and_raise(RuntimeError, "boom")
      expect { described_class.deploy(mode: "shadow", io: io) }.not_to raise_error
      expect(io.string).to include("build_summon_auras (shadow) failed; the deploy continues")
    end

    it "writes the stale summons in write mode" do
      expect(described_class.deploy(mode: "write", io: io)).to have_attributes(built: 2)
      expect(SummonAura.count).to eq(6)
    end
  end
end
