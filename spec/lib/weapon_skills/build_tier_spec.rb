# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::Build do
  let(:registry_class) { WeaponSkills::Build::Rows::Registry }
  let(:registry) do
    effects = ['Voltage', 'Voltage II'].map { |m| registry_class::Effect.new(modifier: m, boost_type: "ex_atk_sp") }
    registry_class.new(data: [], effects: effects)
  end

  def version(name)
    WeaponSkills::BuildResult::Version.new(weapon_granblue_id: "1", position: 0, ordinal: 0,
                                           skill_name_en: name)
  end

  describe ".tier" do
    it "takes the family's II tier for a skill named … II when the canonical data has one" do
      expect(described_class.tier("Voltage", version("Sword Voltage II"), registry)).to eq("Voltage II")
    end

    it "keeps the family otherwise" do
      expect(described_class.tier("Voltage", version("Sword Voltage"), registry)).to eq("Voltage")
      expect(described_class.tier("Might", version("Inferno's Might II"), registry)).to eq("Might")
      expect(described_class.tier("Voltage II", version("Sword Voltage II"), registry)).to eq("Voltage II")
      expect(described_class.tier(nil, version("Sword Voltage II"), registry)).to be_nil
    end
  end
end
