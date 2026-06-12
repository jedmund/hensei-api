# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::InferenceRules do
  describe '.group_role' do
    it 'classifies by subtitle, options title, or transform default' do
      expect(described_class.group_role('', '(Sword form)')).to eq('form_alt')
      expect(described_class.group_role('{{Character/Skills/Options}}', '')).to eq('option')
      expect(described_class.group_role('', '')).to eq('transform_alt')
    end
  end

  describe '.base_role' do
    it 'is conditional when the effect changes based on something (not an options menu)' do
      expect(described_class.base_role('Skill effect changes based on the card', '')).to eq('conditional')
      expect(described_class.base_role('Deal damage', 'options')).to eq('base')
    end
  end

  describe '.ougi_progression' do
    it 'maps label to [role, min_uncap, transcendence_stage]' do
      expect(described_class.ougi_progression('ougi', nil)).to eq(['base', 4, nil])
      expect(described_class.ougi_progression('ougi2', '{{InfoSkillUpgrade|uncap=5}}')).to eq(['uncap_upgrade', 5, nil])
      expect(described_class.ougi_progression('ougi5', 'After Stage 1 Transcendence')).to eq(['transcendence_upgrade', 6, 1])
    end
  end

  describe '.enhanced_role and .transcendence_stage' do
    it 'classifies enhance levels by the transcendence threshold' do
      expect(described_class.enhanced_role(95)).to eq('enhanced')
      expect(described_class.enhanced_role(130)).to eq('transcendence_upgrade')
      expect(described_class.transcendence_stage(150)).to eq(5)
      expect(described_class.transcendence_stage(95)).to be_nil
    end
  end

  describe '.trigger_type_for_text and .trigger_value_for_text' do
    it 'detects stack thresholds and field effects' do
      expect(described_class.trigger_type_for_text('When Causal Intervention is 4')).to eq('stack_threshold')
      expect(described_class.trigger_value_for_text('When Causal Intervention is 4')).to eq('Causal Intervention >= 4')
      expect(described_class.trigger_type_for_text('When Utopia is active')).to eq('field_effect')
      expect(described_class.trigger_value_for_text('When Utopia is active')).to eq('Utopia active')
    end
  end

  describe '.relation_for_role' do
    it 'maps variant roles to link relations' do
      expect(described_class.relation_for_role('option')).to eq('option_of')
      expect(described_class.relation_for_role('transform_alt')).to eq('transforms_to')
    end
  end

  describe 'flag predicates' do
    it 'detects cant_recast, auto_activate, and targets_all from text' do
      expect(described_class.cant_recast?("(Can't recast.)")).to be(true)
      expect(described_class.auto_activate?('(Auto-activates upon taking damage.)')).to be(true)
      expect(described_class.targets_all?('All Dark allies gain X')).to be(true)
    end
  end
end
