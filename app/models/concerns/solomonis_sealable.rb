# frozen_string_literal: true

##
# Evoking Solomonis seal state and unseal priority for GridWeapon and GridSummon.
#
# seal_state: `start` (available from the start), `unsealed` (unsealed during
# the run, runs only) or `sealed`. Null outside Solomonis parties, and on runs
# for slots nobody has filled in yet.
#
# - Starting slots (weapons: mainhand and positions 0 and 1, plus 2 with
#   Justice; summons: the main summon) are always `start`. The model sets it.
# - Builds: everything else is `sealed`, also set by the model. A build never
#   takes a seal state from the client.
# - Runs: everything else is `unsealed`, `sealed` or null, as the client says.
#
# unseal_priority ranks a build's sealed slots in one list across weapons and
# summons. Party#replace_unseal_priority! writes it; removing a ranked row or
# moving it into a starting slot closes the gap.
#
# Substitutes carry no seal state.
module SolomonisSealable
  extend ActiveSupport::Concern

  SEAL_STATES = %w[start unsealed sealed].freeze

  included do
    before_validation :derive_solomonis_seal_state
    validates :seal_state, inclusion: { in: SEAL_STATES }, allow_nil: true
    validates :unseal_priority, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validate :validate_solomonis_seal_state
    after_update :close_unseal_priority_gap, if: -> { saved_change_to_unseal_priority? && unseal_priority.nil? }
    after_destroy :close_unseal_priority_gap, if: -> { unseal_priority.present? }
  end

  # The state this row must have given the party's kind and blessings, keeping
  # a run's own choice for non-starting slots.
  def solomonis_seal_state_for(build:, justice:)
    return 'start' if solomonis_starting_slot?(justice: justice)
    return 'sealed' if build

    seal_state == 'start' ? nil : seal_state
  end

  private

  def solomonis_party?
    !is_substitute? && party&.solomonis?
  end

  # On a Solomonis party, fills in the derived state unless the client set one
  # (an explicit value is checked by #validate_solomonis_seal_state instead).
  def derive_solomonis_seal_state
    return unless solomonis_party?

    unless seal_state_explicit?
      self.seal_state = solomonis_seal_state_for(build: party.solomonis_build?,
                                                 justice: party.solomonis_blessing?(ArcarumBlessing::JUSTICE))
    end
    return if unseal_priority_changed? || seal_state == 'sealed'

    self.unseal_priority = nil
  end

  def seal_state_explicit?
    new_record? ? !seal_state.nil? : seal_state_changed?
  end

  def validate_solomonis_seal_state
    unless solomonis_party?
      errors.add(:seal_state, 'is only for Evoking Solomonis parties') unless seal_state.nil?
      errors.add(:unseal_priority, 'is only for Evoking Solomonis builds') unless unseal_priority.nil?
      return
    end

    build = party.solomonis_build?
    expected = solomonis_seal_state_for(build: build, justice: party.solomonis_blessing?(ArcarumBlessing::JUSTICE))
    if expected == 'start' && seal_state != 'start'
      errors.add(:seal_state, 'must be start for a starting slot')
    elsif expected != 'start' && seal_state == 'start'
      errors.add(:seal_state, 'can only be start for a starting slot')
    elsif build && seal_state != expected
      errors.add(:seal_state, 'is set by the API on builds')
    end

    return if unseal_priority.nil?

    errors.add(:unseal_priority, 'is only for builds') unless build
    errors.add(:unseal_priority, 'is only for sealed slots') unless seal_state == 'sealed'
  end

  def close_unseal_priority_gap
    party&.normalize_unseal_priorities!
  end
end
