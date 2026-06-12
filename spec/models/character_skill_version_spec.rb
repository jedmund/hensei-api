# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkillVersion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:character_skill).inverse_of(:character_skill_versions) }
    it { is_expected.to have_many(:skill_effects).dependent(:destroy).inverse_of(:character_skill_version) }

    it 'defines version link associations' do
      outgoing = described_class.reflect_on_association(:outgoing_links)
      incoming = described_class.reflect_on_association(:incoming_links)

      aggregate_failures do
        expect(outgoing.options[:class_name]).to eq('CharacterSkillVersionLink')
        expect(outgoing.options[:foreign_key]).to eq(:from_version_id)
        expect(outgoing.options[:dependent]).to eq(:destroy)
        expect(outgoing.options[:inverse_of]).to eq(:from_version)
        expect(incoming.options[:class_name]).to eq('CharacterSkillVersionLink')
        expect(incoming.options[:foreign_key]).to eq(:to_version_id)
        expect(incoming.options[:dependent]).to eq(:destroy)
        expect(incoming.options[:inverse_of]).to eq(:to_version)
      end
    end
  end

  describe 'enums' do
    it 'defines type_color enum' do
      expect(described_class.type_colors).to eq(
        'damage' => 'damage',
        'heal' => 'heal',
        'buff' => 'buff',
        'debuff' => 'debuff',
        'field' => 'field'
      )
    end

    it 'defines variant_role enum' do
      expect(described_class.variant_roles).to eq(
        'base' => 'base',
        'enhanced' => 'enhanced',
        'uncap_upgrade' => 'uncap_upgrade',
        'transcendence_upgrade' => 'transcendence_upgrade',
        'transform_alt' => 'transform_alt',
        'option' => 'option',
        'form_alt' => 'form_alt',
        'conditional' => 'conditional'
      )
    end

    it 'defines trigger_type enum' do
      expect(described_class.trigger_types).to eq(
        'none' => 'none',
        'on_cast_toggle' => 'on_cast_toggle',
        'stack_threshold' => 'stack_threshold',
        'field_effect' => 'field_effect',
        'form_state' => 'form_state',
        'menu_select' => 'menu_select',
        'contextual' => 'contextual'
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
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:ordinal) }
    it { is_expected.to validate_numericality_of(:ordinal).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:variant_role) }
  end

  describe 'factory traits' do
    it 'builds expected state variants' do
      aggregate_failures do
        expect(build(:character_skill_version, :transform_alt)).to be_valid
        expect(build(:character_skill_version, :option)).to be_valid
        expect(build(:character_skill_version, :form_alt)).to be_valid
        expect(build(:character_skill_version, :auto)).to be_valid
      end
    end
  end
end
