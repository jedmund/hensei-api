# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::AugmentSkillParser do
  subject(:parser) { described_class.new(log_tag: 'Spec') }

  it 'reads a tier-prefixed Stamina roll from show_value' do
    stamina = create(:weapon_stat_modifier, slug: 'ax_stamina', game_skill_id: 1600)
    param = {
      'augment_skill_info' => [[
        { 'depth' => nil, 'effect_value' => '2.5', 'show_value' => '+2.5%', 'skill_id' => 1589 },
        { 'depth' => nil, 'effect_value' => '2_4', 'show_value' => '+2', 'skill_id' => 1600 }
      ]]
    }

    attrs = parser.attributes(param)

    expect(attrs[:ax_modifier2_id]).to eq(stamina.id)
    expect(attrs[:ax_strength2]).to eq(2.0)
  end

  it 'leaves out skill level and permeation when they are missing or out of range' do
    create(:weapon_stat_modifier, :befoul_atk_down)
    param = {
      'augment_skill_info' => [[{ 'depth' => 9, 'effect_value' => 6.2, 'show_value' => '-6.2%', 'skill_id' => 2873 }]],
      'odiant' => { 'exorcision_level' => 5, 'is_odiant_weapon' => true },
      'skill_level' => ''
    }

    attrs = parser.attributes(param)

    expect(attrs).to include(befoulment_strength: 6.2, exorcism_level: 5)
    expect(attrs).not_to have_key(:befoulment_permeation)
    expect(attrs).not_to have_key(:skill_level)
  end
end
