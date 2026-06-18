# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/extractors/character_grid_effect_extractor")

RSpec.describe Granblue::Extractors::CharacterGridEffectExtractor do
  let(:ex) { described_class.new }

  it "maps an Arche skill to BOTH normal and omega frames for its element" do
    desc = "20% boost to Water's, Tsunami's, Hoarfrost's, and Oceansoul's weapon skills. " \
           "(Takes effect even when Gabriel is a sub ally.)"
    expect(ex.extract(desc)).to contain_exactly(
      hash_including(effect_type: "weapon_skill_boost", frame: "normal", element: "water", amount: 20.0),
      hash_including(effect_type: "weapon_skill_boost", frame: "omega", element: "water", amount: 20.0)
    )
  end

  it "maps an Emissary (omega aura-word only) skill to just the omega frame" do
    expect(ex.extract("10% boost to Oceansoul's weapon skills.")).to contain_exactly(
      hash_including(frame: "omega", element: "water", amount: 10.0)
    )
  end

  it "uses the correct element from the aura words (fire)" do
    desc = "20% boost to Fire's, Hellfire's, Inferno's, and Ironflame's weapon skills."
    frames = ex.extract(desc).group_by { |e| e[:frame] }
    expect(frames["normal"].first).to include(element: "fire", amount: 20.0)
    expect(frames["omega"].first).to include(element: "fire", amount: 20.0)
  end

  it "returns nothing for a non-weapon-skill description" do
    expect(ex.extract("Restore 1500 HP to all allies.")).to be_empty
    expect(ex.extract(nil)).to eq([])
  end
end
