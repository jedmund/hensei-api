# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::Extractors::FamilyTemplateImporter do
  it "does not regenerate condition-owned families as unconditional curve data" do
    candidate = { series: "normal", size: nil, boost_type: "atk", sl1: 3.0, sl10: 8.0 }
    allow(described_class).to receive(:fetch_template).with("Betrayal").and_return("template")
    allow(described_class).to receive(:upsert_family)
    allow(described_class).to receive(:parse_curves).and_return([[candidate], []])

    result = described_class.import_one("Betrayal", apply: true)

    expect(result.missing).to be_empty
    expect(WeaponSkillDatum.where(modifier: "Betrayal")).to be_empty
  end

  it "upserts the family registry row from the WsBox header" do
    raw = <<~WIKI
      {{WsBox
      |aura_boostable=no
      |color=red
      |boost1=Might
      |boost2=HP
      |big=skill_atk_1_3
      |o_big=skill_atk_1_3_o
      }}
    WIKI

    allow(described_class).to receive(:fetch_template).with("Crux").and_return(raw)

    described_class.import_one("Crux")

    family = WeaponSkillFamily.find_by!(name: "Crux")
    expect(family.aura_boostable).to be(false)
    expect(family.boosts).to eq(%w[Might HP])
    expect(family.icon_stems).to eq("normal" => { "big" => "skill_atk_1_3" }, "omega" => { "big" => "skill_atk_1_3_o" })
  end
end
