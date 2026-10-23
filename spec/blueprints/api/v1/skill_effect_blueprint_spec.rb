# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::SkillEffectBlueprint do
  it "exposes the effect's own category" do
    effect = build(:skill_effect, category: 'debuff', effect_type: 'inflict_status')
    expect(JSON.parse(described_class.render(effect))).to include('category' => 'debuff', 'effect_type' => 'inflict_status')
  end

  it "exposes the skill's own name for its status (D57), null when it names the status itself" do
    expect(JSON.parse(described_class.render(build(:skill_effect, label: 'Guilty Break')))).to include('label' => 'Guilty Break')
    expect(JSON.parse(described_class.render(build(:skill_effect)))).to include('label' => nil)
  end
end
