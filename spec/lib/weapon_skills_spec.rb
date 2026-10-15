# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills do
  around do |example|
    original = ENV.fetch("WEAPON_SKILL_BUILD", nil)
    example.run
  ensure
    ENV["WEAPON_SKILL_BUILD"] = original
  end

  it "defaults the build to off and ignores unknown modes" do
    ENV.delete("WEAPON_SKILL_BUILD")
    expect(described_class.build_mode).to eq("off")
    ENV["WEAPON_SKILL_BUILD"] = "sometimes"
    expect(described_class.build_mode).to eq("off")
    ENV["WEAPON_SKILL_BUILD"] = "Shadow"
    expect(described_class.build_mode).to eq("shadow")
  end
end
