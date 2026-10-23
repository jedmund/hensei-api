# frozen_string_literal: true

require "rails_helper"

RSpec.describe SummonAuras::Build::Writer do
  let(:granblue_id) { "2040900001" }

  def record(slot, uncap, value, target: "elemental_atk", stage: 0)
    { "summon_granblue_id" => granblue_id, "slot" => slot, "uncap_level" => uncap, "transcendence_stage" => stage,
      "target" => target, "element" => "water", "value" => value, "condition" => nil,
      "description_en" => "#{value}% boost to Water Elemental ATK." }
  end

  def stored = SummonAura.where(summon_granblue_id: granblue_id)

  it "inserts new tiers" do
    report = described_class.call(granblue_id, [record("main", 0, 50.0), record("sub", 0, 10.0)])
    expect(report).to have_attributes(created: 2, updated: 0, deleted: 0)
    expect(stored.pluck(:slot, :value).sort).to eq([["main", 50], ["sub", 10]])
  end

  it "updates a changed tier in place and leaves unchanged ones alone" do
    described_class.call(granblue_id, [record("main", 0, 50.0), record("main", 3, 80.0)])
    changed = stored.find_by(uncap_level: 0)
    untouched = stored.find_by(uncap_level: 3)

    report = described_class.call(granblue_id, [record("main", 0, 60.0), record("main", 3, 80.0)])
    expect(report).to have_attributes(created: 0, updated: 1, deleted: 0)
    expect(report.changes).to contain_exactly([:updated, ["main", 0, 0], include("value" => [50.0, 60.0])])
    expect(stored.find_by(uncap_level: 0)).to have_attributes(id: changed.id, value: 60)
    expect(stored.find_by(uncap_level: 3).updated_at).to eq(untouched.updated_at)
  end

  it "deletes tiers the build no longer makes" do
    described_class.call(granblue_id, [record("main", 0, 50.0), record("sub", 0, 10.0)])
    report = described_class.call(granblue_id, [record("main", 0, 50.0)])
    expect(report).to have_attributes(deleted: 1)
    expect(stored.pluck(:slot)).to eq(["main"])
  end

  it "leaves description_jp and other summons' rows alone" do
    create(:summon_aura, summon_granblue_id: "2040900002")
    described_class.call(granblue_id, [record("main", 0, 50.0)])
    stored.first.update!(description_jp: "水属性攻撃力が50%UP")

    described_class.call(granblue_id, [record("main", 0, 55.0)])
    expect(stored.first.description_jp).to eq("水属性攻撃力が50%UP")
    expect(SummonAura.where(summon_granblue_id: "2040900002").count).to eq(1)
  end

  it "reports nothing when the build matches the stored rows" do
    described_class.call(granblue_id, [record("main", 0, 50.0)])
    expect(described_class.call(granblue_id, [record("main", 0, 50.0)]).changed?).to be(false)
  end
end
