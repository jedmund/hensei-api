# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::BuildResult do
  let(:version) { described_class::Version.new(weapon_granblue_id: "1040000000", position: 1, ordinal: 0) }

  def row(boost_type, condition = {})
    described_class::Row.new(version_identity: version.identity, kind: :effect, boost_type: boost_type,
                             condition: condition, attributes: {})
  end

  it "identifies versions by weapon, position and ordinal" do
    expect(version.identity).to eq(["1040000000", 1, 0])
  end

  it "rejects two answers for one row identity" do
    result = described_class.new(weapon_granblue_id: "1040000000", versions: [version], rows: [row("atk"), row("atk")])
    expect { result.validate! }.to raise_error(ArgumentError, /duplicate rows/)
  end

  it "accepts rows that differ only by condition" do
    rows = [row("atk"), row("atk", { "turn_lte" => 10 })]
    expect(described_class.new(weapon_granblue_id: "1040000000", versions: [version], rows: rows).validate!).to be_a(described_class)
  end
end
