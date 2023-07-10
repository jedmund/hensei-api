# frozen_string_literal: true

class GridSummon < ApplicationRecord
  belongs_to :party,
             counter_cache: :summons_count,
             inverse_of: :summons
  validates_presence_of :party
  has_one :object, class_name: 'Summon', foreign_key: :id, primary_key: :summon_id

  validate :compatible_with_position, on: :create
  validate :no_conflicts, on: :create

  def summon
    Summon.find(summon_id)
  end

  def blueprint
    GridSummonBlueprint
  end

  # Returns conflicting summons if they exist
  def conflicts(party)
    return unless summon.limit

    party.summons.find do |grid_summon|
      return unless grid_summon.id

      grid_summon if summon.id == grid_summon.summon.id
    end
  end

  private

  # Validates whether there is a conflict with the party
  def no_conflicts
    # Check if the grid summon conflicts with any of the other grid summons in the party
    errors.add(:series, 'must not conflict with existing summons') unless conflicts(party).nil?
  end

  # Validates whether the summon can be added to the desired position
  def compatible_with_position
    return unless [4, 5].include?(position.to_i) && !summon.subaura

    errors.add(:position, 'must have subaura for position')
  end
end
