# frozen_string_literal: true

class DifficultyRule < ApplicationRecord
  validates :name, presence: true
  validates :component, presence: true, inclusion: { in: DifficultyComponent::COMPONENTS }
  validates :rule_type, presence: true, inclusion: { in: ->(_) { PartyDifficulty::Rules.registered_types } }
  validates :weight, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :params_valid_for_rule_type

  after_save :bump_ruleset_version
  after_destroy :bump_ruleset_version

  scope :active, -> { where(active: true) }
  scope :for_component, ->(component) { where(component: component.to_s) }

  def implementation
    @implementation ||= PartyDifficulty::Rules.build(rule_type, params)
  end

  def applies_to?(party)
    implementation.applies?(party)
  end

  def blueprint
    DifficultyRuleBlueprint
  end

  private

  def params_valid_for_rule_type
    return if rule_type.blank? || !PartyDifficulty::Rules.registered_types.include?(rule_type)

    errors.add(:params, "invalid for rule_type #{rule_type}: #{implementation_errors.join(', ')}") unless implementation_errors.empty?
  end

  def implementation_errors
    PartyDifficulty::Rules.validate_params(rule_type, params || {})
  rescue StandardError => e
    [e.message]
  end

  def bump_ruleset_version
    DifficultyConfig.bump_version!
  end
end
