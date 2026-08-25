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

  it "recognizes every current Arche and Emissary passive" do
    cases = {
      "20% boost to Fire's, Hellfire's, Inferno's, and Ironflame's weapon skills." =>
        ["fire", 20.0, %w[normal omega]],
      "20% boost to Water's, Tsunami's, Hoarfrost's, and Oceansoul's weapon skills." =>
        ["water", 20.0, %w[normal omega]],
      "20% boost to Earth's, Mountain's, Terra's, and Lifetree's weapon skills." =>
        ["earth", 20.0, %w[normal omega]],
      "20% boost to Wind's, Whirlwind's, Ventosus's, and Stormwyrm's weapon skills." =>
        ["wind", 20.0, %w[normal omega]],
      "20% boost to Light's, Thunder's, Zion's, and Knightcode's skill effects." =>
        ["light", 20.0, %w[normal omega]],
      "20% boost to Dark's, Hatred's, Oblivion's, and Mistfall's weapon skills." =>
        ["dark", 20.0, %w[normal omega]],
      "10% boost to Ironflame's weapon skills." => ["fire", 10.0, %w[omega]],
      "10% boost to Oceansoul's weapon skills." => ["water", 10.0, %w[omega]],
      "10% boost to Lifetree's weapon skills." => ["earth", 10.0, %w[omega]],
      "10% boost to Stormwyrm's weapon skills." => ["wind", 10.0, %w[omega]],
      "10% boost to Knightcode's weapon skills." => ["light", 10.0, %w[omega]],
      "10% boost to Mistfall's weapon skills." => ["dark", 10.0, %w[omega]]
    }

    cases.each do |description, (element, amount, frames)|
      effects = ex.extract(description, element: element)
      expect(effects.map { |effect| effect.values_at(:frame, :element, :amount) }).to contain_exactly(
        *frames.map { |frame| [frame, element, amount] }
      ), description
    end
  end

  it "rejects aura words that do not match the character's element" do
    description = "20% boost to Light's, Thunder's, Zion's, and Knightcode's skill effects."

    expect(ex.extract(description, element: "earth")).to be_empty
  end

  it "uses the correct element from the aura words (fire)" do
    desc = "20% boost to Fire's, Hellfire's, Inferno's, and Ironflame's weapon skills."
    frames = ex.extract(desc).group_by { |e| e[:frame] }
    expect(frames["normal"].first).to include(element: "fire", amount: 20.0)
    expect(frames["omega"].first).to include(element: "fire", amount: 20.0)
  end

  it "returns nothing for an unrelated description" do
    expect(ex.extract("Restore 1500 HP to all allies.")).to be_empty
    expect(ex.extract(nil)).to eq([])
  end
end
