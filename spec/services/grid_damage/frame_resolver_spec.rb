# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::FrameResolver do
  def weapon(slug:, name:)
    double(weapon_series: slug && double(slug: slug), name_en: name)
  end

  def version(series)
    double(skill_series: series)
  end

  it "uses the explicit aura-word series when the skill has one" do
    expect(described_class.frame_for(weapon(slug: "dark-opus", name: "x"), version("omega"))).to eq("omega")
    expect(described_class.frame_for(weapon(slug: nil, name: "x"), version("ex"))).to eq("ex")
  end

  it "frames Dark Opus by weapon identity" do
    w_rep = weapon(slug: "dark-opus", name: "Staff of Repudiation")
    w_ren = weapon(slug: "dark-opus", name: "Staff of Renunciation")
    expect(described_class.frame_for(w_rep, version(nil))).to eq("normal")
    expect(described_class.frame_for(w_ren, version(nil))).to eq("omega")
  end

  it "frames the Draconic base Progression as EX" do
    expect(described_class.frame_for(weapon(slug: "draconic", name: "Draconic Rod"), version(nil))).to eq("ex")
    expect(described_class.frame_for(weapon(slug: "draconic-providence", name: "x"), version(nil))).to eq("ex")
  end

  it "defaults to normal otherwise" do
    expect(described_class.frame_for(weapon(slug: "magna", name: "x"), version(nil))).to eq("normal")
    expect(described_class.frame_for(weapon(slug: nil, name: "x"), version(nil))).to eq("normal")
  end
end
