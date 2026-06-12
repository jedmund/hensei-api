# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SkillEffect, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:character_skill_version).inverse_of(:skill_effects) }
    it { is_expected.to belong_to(:status).optional }
  end

  describe 'enums' do
    it 'defines effect_type enum' do
      expect(described_class.effect_types).to eq(
        'grant_status' => 'grant_status',
        'inflict_status' => 'inflict_status',
        'deal_damage' => 'deal_damage',
        'heal' => 'heal',
        'dispel' => 'dispel',
        'cooldown_manip' => 'cooldown_manip',
        'charge_manip' => 'charge_manip',
        'field_effect' => 'field_effect',
        'summon_object' => 'summon_object',
        'other' => 'other'
      )
    end

    it 'defines target enum' do
      expect(described_class.targets).to eq(
        'caster' => 'caster',
        'one_ally' => 'one_ally',
        'all_allies' => 'all_allies',
        'element_allies' => 'element_allies',
        'one_foe' => 'one_foe',
        'all_foes' => 'all_foes',
        'field' => 'field'
      )
    end

    it 'defines duration_unit enum' do
      expect(described_class.duration_units).to eq(
        'turns' => 'turns',
        'half_turns' => 'half_turns',
        'seconds' => 'seconds',
        'indefinite' => 'indefinite',
        'one_time' => 'one_time',
        'none' => 'none'
      )
    end

    it 'defines stacking_frame enum' do
      expect(described_class.stacking_frames).to eq(
        'normal' => 'normal',
        'summon' => 'summon',
        'unique' => 'unique',
        'seraphic' => 'seraphic',
        'ex' => 'ex',
        'assassin' => 'assassin'
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:ordinal) }
    it { is_expected.to validate_presence_of(:effect_type) }

    it 'allows target and status to be nil' do
      effect = build(:skill_effect, target: nil, status: nil)

      expect(effect).to be_valid
    end
  end

  describe 'factory traits' do
    it 'builds non-status effects' do
      aggregate_failures do
        expect(build(:skill_effect, :damage)).to be_valid
        expect(build(:skill_effect, :heal)).to be_valid
      end
    end
  end
end
