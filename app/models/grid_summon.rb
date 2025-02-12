# frozen_string_literal: true

##
# Model representing a grid summon within a party.
#
# A GridSummon is associated with a specific {Summon} and {Party} and is responsible for
# enforcing rules on positions, uncap levels, and transcendence steps based on the associated summon’s flags.
#
# @!attribute [r] summon
#   @return [Summon] the associated summon.
# @!attribute [r] party
#   @return [Party] the associated party.
class GridSummon < ApplicationRecord
  belongs_to :summon, foreign_key: :summon_id, primary_key: :id

  belongs_to :party,
             counter_cache: :summons_count,
             inverse_of: :summons
  validates_presence_of :party

  # Validate that position is provided.
  validates :position, presence: true
  validate :compatible_with_position, on: :create

  # Validate that uncap_level and transcendence_step are present and numeric.
  validates :uncap_level, presence: true, numericality: { only_integer: true }
  validates :transcendence_step, presence: true, numericality: { only_integer: true }

  # Custom validation to enforce maximum uncap_level based on the associated Summon’s flags.
  validate :validate_uncap_level_based_on_summon_flags

  validate :no_conflicts, on: :create

  ##
  # Returns the blueprint for rendering the grid summon.
  #
  # @return [GridSummonBlueprint] the blueprint class for grid summons.
  def blueprint
    GridSummonBlueprint
  end

  ##
  # Returns any conflicting grid summon for the given party.
  #
  # If the associated summon has a limit, this method searches the party's grid summons to find
  # any that conflict based on the summon ID.
  #
  # @param party [Party] the party in which to check for conflicts.
  # @return [GridSummon, nil] the conflicting grid summon if found, otherwise nil.
  def conflicts(party)
    return unless summon.limit

    party.summons.find do |grid_summon|
      return unless grid_summon.id

      grid_summon if summon.id == grid_summon.summon.id
    end
  end

  private

  ##
  # Validates the uncap_level based on the associated Summon’s flags.
  #
  # This method delegates to specific validation methods for FLB, ULB, and transcendence limits.
  #
  # @return [void]
  def validate_uncap_level_based_on_summon_flags
    return unless summon

    validate_flb_limit
    validate_ulb_limit
    validate_transcendence_limits
  end

  ##
  # Validates that the uncap_level does not exceed 3 if the associated Summon does not have the FLB flag.
  #
  # @return [void]
  def validate_flb_limit
    return unless !summon.flb && uncap_level.to_i > 3

    errors.add(:uncap_level, 'cannot be greater than 3 if summon does not have FLB')
  end

  ##
  # Validates that the uncap_level does not exceed 4 if the associated Summon does not have the ULB flag.
  #
  # @return [void]
  def validate_ulb_limit
    return unless !summon.ulb && uncap_level.to_i > 4

    errors.add(:uncap_level, 'cannot be greater than 4 if summon does not have ULB')
  end

  ##
  # Validates the uncap_level and transcendence_step based on whether the associated Summon supports transcendence.
  #
  # If the summon does not support transcendence, the uncap_level must not exceed 5 and the transcendence_step must be 0.
  #
  # @return [void]
  def validate_transcendence_limits
    return if summon.transcendence

    errors.add(:uncap_level, 'cannot be greater than 5 if summon does not have transcendence') if uncap_level.to_i > 5

    return unless transcendence_step.to_i.positive?

    errors.add(:transcendence_step, 'must be 0 if summon does not have transcendence')
  end

  ##
  # Validates that there are no conflicting grid summons in the party.
  #
  # If a conflict is found (i.e. another grid summon exists that conflicts with this one),
  # an error is added to the :series attribute.
  #
  # @return [void]
  def no_conflicts
    # Check if the grid summon conflicts with any of the other grid summons in the party
    errors.add(:series, 'must not conflict with existing summons') unless conflicts(party).nil?
  end

  ##
  # Validates whether the grid summon can be added to the desired position.
  #
  # For positions 4 and 5, the associated summon must have subaura; otherwise, an error is added.
  #
  # @return [void]
  def compatible_with_position
    return unless [4, 5].include?(position.to_i) && !summon.subaura

    errors.add(:position, 'must have subaura for position')
  end
end
