# frozen_string_literal: true

class GridSummon < ApplicationRecord
  belongs_to :party

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

    party.summons.find do |party_summon|
      ap 'Normal summon:'
      ap summon
      ap 'Party summon:'
      ap party_summon

      summon if summon.id == party_summon.summon.id
    end
  end

  private

  # Validates whether there is a conflict with the party
  def no_conflicts
    ap conflicts(party)

    # Check if the grid weapon conflicts with any of the other grid weapons in the party
    errors.add(:series, 'must not conflict with existing summons') unless conflicts(party).nil?
  end

  # Validates whether the weapon can be added to the desired position
  def compatible_with_position
    ap [4, 5].include?(position.to_i) && !summon.subaura
    return unless [4, 5].include?(position.to_i) && !summon.subaura

    errors.add(:position, 'must have subaura for position')
  end
end
