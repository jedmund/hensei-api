# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::Build::Fingerprint do
  let(:weapon) { create(:weapon, granblue_id: "1040000001") }
  let(:other) { create(:weapon, granblue_id: "1040000002") }
  let(:entries) do
    { "versions" => [{ "weapon" => "1040000001", "skill" => "Might", "ordinal" => 0, "series_override" => "normal" },
                     { "weapon" => "1040000002", "skill" => "Might", "ordinal" => 0, "series_override" => "omega" }],
      "ops" => [{ "op" => "gate", "weapon" => "1040000001", "skill" => "Might", "ordinal" => 0, "unlock_level" => 100 }] }
  end

  def context(sections = entries, files: nil)
    overlay = Granblue::CurationSnapshot::Overlay.new(files || [["spec.json", sections]])
    WeaponSkills::Build::Context.new(store: WeaponSkills::SourceStore::Memory.new, overlay: overlay)
  end

  def source(owner, kind, key, body)
    WeaponSource.create!(weapon: owner, kind: kind, key: key, body: body, fetched_at: Time.current)
  end

  def fingerprint(ctx = context, of: weapon) = described_class.for(of, context: ctx)

  before do
    source(weapon, "wiki_raw", "Sword", "page")
    source(weapon, "expanded", "Sword", "expanded page")
    source(weapon, "transclusion", "Template:Series", "series")
    source(nil, "family_template", "Template:WeaponSkill/Might", "might table")
  end

  it "is a stable SHA256 hex digest" do
    expect(fingerprint).to match(/\A\h{64}\z/)
    expect(fingerprint).to eq(fingerprint)
  end

  it "changes when one of the weapon's sources changes" do
    before = fingerprint
    WeaponSource.find_by(weapon: weapon, kind: "transclusion").update!(body: "series, edited")
    expect(fingerprint).not_to eq(before)
  end

  it "changes when a family template changes" do
    before = fingerprint
    WeaponSource.find_by(kind: "family_template").update!(body: "might table, edited")
    expect(fingerprint).not_to eq(before)
  end

  it "changes when the weapon's overlay entry changes" do
    edited = entries.deep_dup.tap { |e| e["versions"][0]["series_override"] = "omega" }
    expect(fingerprint(context(edited))).not_to eq(fingerprint)
  end

  it "changes when Build::VERSION changes" do
    before = fingerprint
    stub_const("WeaponSkills::Build::VERSION", WeaponSkills::Build::VERSION + 1)
    expect(fingerprint).not_to eq(before)
  end

  it "ignores fetch times and another weapon's sources and overlay entries" do
    before = fingerprint
    WeaponSource.where(weapon: weapon).update_all(fetched_at: 1.day.ago)
    source(other, "wiki_raw", "Other", "other page")
    edited = entries.deep_dup.tap { |e| e["versions"][1]["series_override"] = "normal" }
    expect(fingerprint(context(edited))).to eq(before)
  end

  it "doesn't depend on entry, key or file order" do
    shuffled = entries.transform_values { |list| list.reverse.map { |e| e.to_a.reverse.to_h } }
    split = [["b.json", { "ops" => entries["ops"] }], ["a.json", { "versions" => entries["versions"] }]]
    expect(fingerprint(context(shuffled))).to eq(fingerprint)
    expect(fingerprint(context(files: split))).to eq(fingerprint)
  end

  it "gives the same result with preloaded sources" do
    expect(described_class.new(context).preload_sources!.for(weapon)).to eq(fingerprint)
  end
end
