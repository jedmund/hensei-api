# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::ParitySnapshot do
  let(:version) { create(:weapon_skill_version, unlock_level: 150, min_uncap: 4) }
  let!(:datum) do
    create(:weapon_skill_datum, weapon_skill_version_id: version.id, modifier: version.skill.name_en,
                                boost_type: "atk", series: "ex", sl1: 3.5, sl10: 10, sl15: 12)
  end

  def key_for(record)
    [record.weapon_skill.weapon_granblue_id, record.weapon_skill.position, record.ordinal, record.skill.name_en].join("|")
  end

  it "records each version's gate, frame and resolved rows with plain floats" do
    entry = described_class.capture["versions"].fetch(key_for(version))

    expect(entry["gate"]).to eq([150, 4, 0])
    row = described_class.data_columns.zip(entry["data"].first).to_h
    expect(row.slice("boost_type", "formula_type", "sl1", "sl10", "sl15"))
      .to eq("boost_type" => "atk", "formula_type" => "flat", "sl1" => 3.5, "sl10" => 10.0, "sl15" => 12.0)
    expect(entry["effects"]).to eq([])
  end

  it "reports changed, missing and added versions" do
    before = described_class.capture
    datum.update!(sl15: 13)
    other = create(:weapon_skill_version)
    after = described_class.capture

    diff = described_class.diff(before, after)
    expect(diff["changed"].map { |c| c["key"] }).to eq([key_for(version)])
    expect(diff["changed"].first["fields"].keys).to eq(["data"])
    expect(diff["added"]).to eq([key_for(other)])
    expect(described_class.empty_diff?(described_class.diff(after, after))).to be(true)
  end

  it "captures the same snapshot regardless of row order" do
    create(:weapon_skill_datum, weapon_skill_version_id: version.id, modifier: version.skill.name_en,
                                boost_type: "hp", series: "ex")
    first = described_class.capture["versions"]
    WeaponSkillDatum.where(weapon_skill_version_id: version.id).find_each(&:touch)
    expect(described_class.capture["versions"]).to eq(first)
  end
end
