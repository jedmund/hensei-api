# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::SkillEffectBlueprint do
  it "exposes the effect's own category" do
    effect = build(:skill_effect, category: 'debuff', effect_type: 'inflict_status')
    expect(JSON.parse(described_class.render(effect))).to include('category' => 'debuff', 'effect_type' => 'inflict_status')
  end
end
