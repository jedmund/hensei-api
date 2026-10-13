# frozen_string_literal: true

##
# Party-wide Evoking Solomonis seal state and unseal priority (see
# SolomonisSealable for the per-row rules). Included through SolomonisParty.
module SolomonisPartySeals
  extend ActiveSupport::Concern

  ##
  # Replaces the unseal priority list. Items are loaded from this party
  # (never trusted from params), must be sealed, and are numbered from 1 in
  # the order given. Slots left out lose their priority.
  #
  # @param items [Array<Hash>] `{ type: 'weapon' | 'summon', id: }` in order
  # @raise [ActiveRecord::RecordInvalid] with errors on :unseal_priority
  def replace_unseal_priority!(items)
    errors.clear
    errors.add(:unseal_priority, 'is only for Evoking Solomonis parties') unless solomonis?
    raise ActiveRecord::RecordInvalid, self if errors.any?

    weapons_by_id = GridWeapon.where(party_id: id, is_substitute: false).index_by(&:id)
    summons_by_id = GridSummon.where(party_id: id, is_substitute: false).index_by(&:id)
    rows = items.to_a.map do |item|
      item = item.to_h.with_indifferent_access
      case item[:type].to_s
      when 'weapon' then weapons_by_id[item[:id]]
      when 'summon' then summons_by_id[item[:id]]
      end
    end

    if rows.any?(&:nil?)
      errors.add(:unseal_priority, 'includes an item that is not in this party')
    elsif rows.uniq.size != rows.size
      errors.add(:unseal_priority, 'lists an item more than once')
    elsif rows.any? { |row| row.seal_state != 'sealed' }
      errors.add(:unseal_priority, 'can only rank sealed items')
    end
    raise ActiveRecord::RecordInvalid, self if errors.any?

    transaction do
      GridWeapon.where(party_id: id).where.not(unseal_priority: nil).update_all(unseal_priority: nil)
      GridSummon.where(party_id: id).where.not(unseal_priority: nil).update_all(unseal_priority: nil)
      rows.each_with_index { |row, index| row.update_columns(unseal_priority: index + 1) }
    end
    rows
  end

  ##
  # Re-derives seal state and unseal priority for the whole party: starting
  # slots become `start`; a slot that was `start` but no longer starts
  # (Justice removed) or has no state becomes `sealed`; other slots keep their
  # state. Priorities on slots that aren't sealed are dropped and the list is
  # renumbered from 1 without gaps.
  #
  # Writes with update_columns, so no grid callbacks fire. Safe to call after
  # any grid or blessing change; does nothing outside Solomonis.
  def recompute_solomonis_state!
    expedition = SolomonisExpedition.find_by(party_id: id)
    return unless expedition

    justice = PartyBlessing.joins(:arcarum_blessing)
                           .where(party_id: id, arcarum_blessings: { slug: ArcarumBlessing::JUSTICE }).exists?
    weapons = GridWeapon.where(party_id: id, is_substitute: false).to_a
    summons = GridSummon.where(party_id: id, is_substitute: false).to_a

    (weapons + summons).each do |row|
      state = row.solomonis_seal_state_for(justice: justice)
      row.unseal_priority = nil unless state == 'sealed'
      row.seal_state = state
    end

    ranked = (weapons + summons).select(&:unseal_priority)
                                .sort_by { |row| unseal_priority_sort_key(row) }
    ranked.each_with_index { |row, index| row.unseal_priority = index + 1 }

    (weapons + summons).each do |row|
      changes = row.changes_to_save.slice('seal_state', 'unseal_priority').transform_values(&:last)
      row.update_columns(changes) if changes.any?
    end
  end

  ##
  # Sets imported seal state by grid position, then re-derives the rest
  # (starting slots stay `start` whatever the import says). Slots not listed
  # keep their state.
  #
  # @param weapons [Hash{Integer => String}] weapon position => 'sealed' | 'unsealed'
  # @param summons [Hash{Integer => String}] summon position => 'sealed' | 'unsealed'
  def apply_solomonis_seal_states!(weapons: {}, summons: {})
    return unless SolomonisExpedition.exists?(party_id: id)

    { GridWeapon => weapons, GridSummon => summons }.each do |model, states|
      next if states.empty?

      model.where(party_id: id, is_substitute: false, position: states.keys).find_each do |row|
        state = states[row.position]
        next unless SolomonisSealable::SEAL_STATES.include?(state) && state != 'start'

        row.update_columns(seal_state: state, unseal_priority: state == 'sealed' ? row.unseal_priority : nil)
      end
    end
    recompute_solomonis_state!
  end

  ##
  # Closes gaps in the unseal priority list (after a ranked item is
  # removed or stops being sealed). A no-op when the list is already 1..n.
  def normalize_unseal_priorities!
    rows = GridWeapon.where(party_id: id, is_substitute: false).where.not(unseal_priority: nil).to_a +
           GridSummon.where(party_id: id, is_substitute: false).where.not(unseal_priority: nil).to_a
    rows.sort_by { |row| unseal_priority_sort_key(row) }
        .each_with_index do |row, index|
      row.update_columns(unseal_priority: index + 1) if row.unseal_priority != index + 1
    end
  end

  private

  def unseal_priority_sort_key(row)
    [row.unseal_priority, row.is_a?(GridWeapon) ? 0 : 1, row.position.to_i]
  end
end
