# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridDamage::CharacterAuras do
  let(:party) { create(:party) }

  def add_passive(granblue_id:, name:, position:, frames:, amount:)
    character = create(:character, granblue_id: granblue_id, name_en: name, element: 6)
    skill = create(:character_skill, :support, character: character, position: 2)
    version = create(:character_skill_version, character_skill: skill)
    frames.each_with_index do |frame, index|
      create(:skill_effect, character_skill_version: version, status: nil,
                            ordinal: index + 1, effect_type: :weapon_skill_boost,
                            target: :element_allies, frame: frame, element: 'light', amount: amount)
    end
    create(:grid_character, party: party, character: character, position: position, uncap_level: 4)
  end

  it 'counts backline Arche and Emissary passives in their respective frames' do
    add_passive(granblue_id: '3040515000', name: 'Sandalphon (Grand)', position: 4,
                frames: %w[normal omega], amount: 20)
    add_passive(granblue_id: '3040587000', name: 'Pijiu', position: 5,
                frames: %w[omega], amount: 10)

    expect(described_class.for_party(party, element: 'light')).to eq(optimus: 20.0, omega: 30.0)
  end

  it 'does not apply those effects to a grid of another element' do
    add_passive(granblue_id: '3040515000', name: 'Sandalphon (Grand)', position: 4,
                frames: %w[normal omega], amount: 20)

    expect(described_class.for_party(party, element: 'earth')).to eq(optimus: 0.0, omega: 0.0)
  end
end
