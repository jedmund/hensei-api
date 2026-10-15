# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::OverlaySchema do
  let(:ref) { { "weapon" => "1040020800", "skill" => "Water's Majesty", "ordinal" => 0, "edited_at" => "2026-10-15T00:00:00Z" } }

  it "accepts every section and op from overlay-v2.md" do
    doc = {
      "format" => 2,
      "versions" => [ref.merge("size_override" => "big")],
      "effects" => [ref.merge("modifier" => "Water's Majesty", "boost_type" => "atk")],
      "data" => [{ "modifier" => "Might", "boost_type" => "atk", "edited_at" => "2026-10-15T00:00:00Z" }],
      "ops" => [
        ref.merge("op" => "add_version", "position" => 4, "min_uncap" => 5, "reason" => "gbf.wiki: Weapon page"),
        ref.merge("op" => "gate", "unlock_level" => 200, "reason" => "gbf.wiki"),
        ref.merge("op" => "remove_version", "reason" => "not in game"),
        ref.merge("op" => "description", "description_en" => "Big boost to ATK", "reason" => "tier II text")
      ]
    }
    expect(described_class.validate(doc)).to eq([])
  end

  it "requires a format, a citation on ops, and a full version reference" do
    doc = { "ops" => [{ "op" => "gate", "weapon" => "1040020800", "unlock_level" => 200, "edited_at" => "x" }] }
    errors = described_class.validate(doc)

    expect(errors).to include("format must be 2")
    expect(errors.join).to include("reason is required", "skill is required", "ordinal must be an integer",
                                   "edited_at must be an ISO 8601 time")
  end

  it "rejects unknown ops and empty gates" do
    doc = { "format" => 2, "ops" => [ref.merge("op" => "rename", "reason" => "x"), ref.merge("op" => "gate", "reason" => "x")] }
    expect(described_class.validate(doc).join).to include("op must be one of", "gate needs at least one")
  end
end
