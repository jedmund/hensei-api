# frozen_string_literal: true

##
# Evoking Solomonis seal state and unseal priority for GridWeapon and GridSummon.
#
# seal_state: `start` (available from the start), `unsealed` (unsealed during
# the expedition) or `sealed`. Null outside Solomonis parties.
#
# - Starting slots (weapons: mainhand and positions 0 and 1, plus 2 with
#   Justice; summons: the main summon) are always `start`. The model sets it.
# - Every other slot is `sealed` or `unsealed`, as the client (or an import)
#   says. A slot nobody has set, or one that stops being a starting slot
#   (Justice removed, moved out of a starting position), is `sealed`.
#
# unseal_priority ranks the party's sealed slots in two independent lists,
# one for weapons and one for summons, each numbered from 1.
# Party#replace_unseal_priority! writes them; removing a ranked row, unsealing
# it or moving it into a starting slot closes the gap in its own list.
#
# Substitutes carry no seal state.
module SolomonisSealable
  extend ActiveSupport::Concern

  SEAL_STATES = %w[start unsealed sealed].freeze
  # State of a non-starting slot nobody has set.
  DEFAULT_SEAL_STATE = 'sealed'

  included do
    before_validation :derive_solomonis_seal_state
    validates :seal_state, inclusion: { in: SEAL_STATES }, allow_nil: true
    validates :unseal_priority, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validate :validate_solomonis_seal_state
    after_update :close_unseal_priority_gap, if: -> { saved_change_to_unseal_priority? && unseal_priority.nil? }
    after_destroy :close_unseal_priority_gap, if: -> { unseal_priority.present? }
  end

  # The state this row must have given the party's blessings, keeping the
  # current choice for non-starting slots.
  def solomonis_seal_state_for(justice:)
    return 'start' if solomonis_starting_slot?(justice: justice)
    return DEFAULT_SEAL_STATE if seal_state.nil? || seal_state == 'start'

    seal_state
  end

  private

  def solomonis_party?
    !is_substitute? && party&.solomonis?
  end

  # On a Solomonis party, fills in the derived state unless the client set one
  # (an explicit value is checked by #validate_solomonis_seal_state instead).
  # An explicit null means "not set", so it gets the default.
  def derive_solomonis_seal_state
    return unless solomonis_party?

    if !seal_state_explicit? || seal_state.nil?
      self.seal_state = solomonis_seal_state_for(justice: party.solomonis_blessing?(ArcarumBlessing::JUSTICE))
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
      errors.add(:unseal_priority, 'is only for Evoking Solomonis parties') unless unseal_priority.nil?
      return
    end

    starting = solomonis_starting_slot?(justice: party.solomonis_blessing?(ArcarumBlessing::JUSTICE))
    if starting && seal_state != 'start'
      errors.add(:seal_state, 'must be start for a starting slot')
    elsif !starting && seal_state == 'start'
      errors.add(:seal_state, 'can only be start for a starting slot')
    end

    return if unseal_priority.nil? || seal_state == 'sealed'

    errors.add(:unseal_priority, 'is only for sealed slots')
  end

  def close_unseal_priority_gap
    party&.normalize_unseal_priorities!
  end
end
