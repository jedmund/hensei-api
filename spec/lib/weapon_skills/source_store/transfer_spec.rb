# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::SourceStore::Transfer do
  let(:path) { Rails.root.join("tmp/transfer_spec_#{SecureRandom.hex(4)}.jsonl.gz") }
  let(:weapon) { create(:weapon, name_en: "Ray of Zhuque Regus", wiki_en: "Ray of Zhuque Regus", wiki_raw: "old page") }
  let(:fetched_at) { Time.utc(2026, 10, 15, 13, 27) }

  after { FileUtils.rm_f(path) }

  def source(kind, key, body, weapon: nil, at: fetched_at)
    WeaponSource.create!(weapon: weapon, kind: kind, key: key, body: body, fetched_at: at,
                         page_kind: kind == "wiki_raw" && weapon ? "inline" : nil)
  end

  # Export from "local", then reset the table to stand in for the target database.
  def export_and_clear
    described_class.export(path)
    WeaponSource.delete_all
    described_class.read(path).last
  end

  it "round-trips every row and writes each weapon's page to weapons.wiki_raw" do
    weapon.update_columns(wiki_raw_fetched_at: Time.utc(2026, 6, 17))
    source("wiki_raw", "Ray_of_Zhuque_Regus", "|id=1040906500", weapon: weapon)
    source("transclusion", "Template:Weapon/Common/Six", "{{template}}", weapon: weapon)
    source("family_template", "Template:Weapon Skills/Might", "family")
    rows = export_and_clear

    plan = described_class.plan(rows)
    expect(plan.counts).to include(added: 3, weapon_pages: 1)
    expect(WeaponSource.count).to eq(0) # planning writes nothing

    described_class.apply(plan)

    expect(WeaponSource.pluck(:kind, :key, :body, :fetched_at)).to contain_exactly(
      ["wiki_raw", "Ray of Zhuque Regus", "|id=1040906500", fetched_at],
      ["transclusion", "Template:Weapon/Common/Six", "{{template}}", fetched_at],
      ["family_template", "Template:Weapon Skills/Might", "family", fetched_at]
    )
    expect(weapon.reload).to have_attributes(wiki_raw: "|id=1040906500", wiki_raw_fetched_at: fetched_at)
    expect(described_class.plan(rows).counts).to eq(unchanged: 3)
  end

  it "stamps a weapon whose page is unchanged with the stored fetch time" do
    weapon.update_columns(wiki_raw: "same", wiki_raw_fetched_at: Time.utc(2026, 6, 17))
    source("wiki_raw", "Ray of Zhuque Regus", "same", weapon: weapon)
    rows = export_and_clear

    described_class.apply(described_class.plan(rows))

    expect(weapon.reload).to have_attributes(wiki_raw: "same", wiki_raw_fetched_at: fetched_at)
    expect(described_class.plan(rows).weapon_updates).to be_empty
  end

  it "keeps a row fetched after the exported one" do
    source("wiki_raw", "Ray_of_Zhuque_Regus", "exported", weapon: weapon)
    rows = export_and_clear
    source("wiki_raw", "Ray_of_Zhuque_Regus", "newer", weapon: weapon, at: fetched_at + 1.day)
    weapon.update_columns(wiki_raw: "newer", wiki_raw_fetched_at: fetched_at + 1.day)

    plan = described_class.plan(rows)

    expect(plan.counts).to include(kept_newer: 1)
    expect(plan.inserts).to be_empty
    expect(plan.weapon_updates).to be_empty
  end

  it "replaces an older row" do
    source("wiki_raw", "Ray_of_Zhuque_Regus", "exported", weapon: weapon)
    rows = export_and_clear
    source("wiki_raw", "Ray_of_Zhuque_Regus", "older", weapon: weapon, at: fetched_at - 1.day)

    described_class.apply(described_class.plan(rows))

    expect(WeaponSource.sole.body).to eq("exported")
  end

  it "skips rows whose weapon is missing or named differently" do
    other = create(:weapon, name_en: "Ray of Zhuque Pontus")
    source("wiki_raw", "Ray_of_Zhuque_Regus", "page", weapon: weapon)
    source("wiki_raw", "Ray_of_Zhuque_Pontus", "page", weapon: other)
    rows = export_and_clear
    weapon.update_columns(name_en: "Something Else")
    other.destroy!

    plan = described_class.plan(rows)

    expect(plan.counts).to include(weapon_renamed: 1, weapon_missing: 1)
    expect(plan.inserts).to be_empty
    expect(plan.problems.size).to eq(2)
  end

  it "imports titles in canonical form, keeping the newer of two that normalize alike" do
    weapon.update_columns(wiki_en: "Devil%27s_Finger")
    source("expanded", "Devil's Finger", "older", weapon: weapon, at: fetched_at - 1.day)
    WeaponSource.create!(weapon: weapon, kind: "expanded", key: "Devil's_Finger", body: "newer", fetched_at: fetched_at)
    WeaponSource.where(body: "newer").update_all(key: "Devil%27s_Finger")
    rows = export_and_clear

    plan = described_class.plan(rows)
    described_class.apply(plan)

    expect(plan.counts).to include(duplicate_title: 1)
    expect(WeaponSource.pluck(:key, :body)).to eq([["Devil's Finger", "newer"]])
  end

  it "refuses a file whose body doesn't match its checksum" do
    source("family_template", "Template:Weapon Skills/Might", "family")
    rows = export_and_clear
    rows.first["body"] = "tampered"

    expect { described_class.plan(rows) }.to raise_error(ArgumentError, /checksum/)
  end
end
