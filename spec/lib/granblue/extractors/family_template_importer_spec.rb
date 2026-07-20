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
end
