# frozen_string_literal: true

##
# Keeps the Notes pane (description + substitutions) in lockstep across every
# grid item in a party that shares the same canonical weapon/summon.
#
# A "sync group" is the set of GridWeapons (or GridSummons) in a single party
# that point to the same Weapon (or Summon) and have +notes_synced+ true.
# Toggling the flag on any one item propagates to every sibling; writes to a
# synced item's description or substitutions fan out to siblings inside a
# single transaction so the group can't drift.
module NotesSync
  module_function

  ##
  # Returns sibling grid items in the same party that share this item's
  # canonical reference. Excludes the item itself.
  #
  # @param item [GridWeapon, GridSummon]
  # @return [ActiveRecord::Relation<GridWeapon, GridSummon>]
  def siblings(item)
    case item
    when GridWeapon
      item.party.weapons.where(weapon_id: item.weapon_id).where.not(id: item.id)
    when GridSummon
      item.party.summons.where(summon_id: item.summon_id).where.not(id: item.id)
    else
      # GridCharacter and anything else aren't part of any sync group.
      nil
    end
  end

  ##
  # True for grid item types that carry the notes_synced flag.
  def syncable?(item)
    item.is_a?(GridWeapon) || item.is_a?(GridSummon)
  end

  ##
  # If the item is in a sync group, copy its description to every sibling.
  # No-op when notes_synced is false.
  def propagate_description!(item)
    return false unless syncable?(item) && item.notes_synced?

    siblings(item).update_all(description: item.description, updated_at: Time.current)
    true
  end

  ##
  # Replaces each sibling's substitutions with a mirror of this item's set.
  # Same (position, substitute_grid) tuples; only the primary grid pointer
  # differs. Rows that would make a sibling substitute itself are skipped
  # (the Substitution model rejects that case anyway).
  def propagate_substitutions!(item)
    return false unless syncable?(item) && item.notes_synced?

    grid_type = item.class.name
    source_subs = item.substitutions.to_a

    ActiveRecord::Base.transaction do
      siblings(item).find_each do |sibling|
        sibling.substitutions.destroy_all

        source_subs.each do |sub|
          next if sub.substitute_grid_id == sibling.id && sub.substitute_grid_type == grid_type

          sibling.substitutions.create!(
            substitute_grid_id: sub.substitute_grid_id,
            substitute_grid_type: sub.substitute_grid_type,
            position: sub.position
          )
        end
      end
    end
    true
  end

  ##
  # Flips notes_synced on this item AND every sibling, then immediately
  # mirrors this item's description + substitutions across the group so the
  # newly-joined siblings adopt the editing item's state.
  def enable_sync!(item)
    return false unless syncable?(item)

    ActiveRecord::Base.transaction do
      item.update_column(:notes_synced, true) unless item.notes_synced?
      siblings(item).update_all(notes_synced: true, updated_at: Time.current)
      propagate_description!(item)
      propagate_substitutions!(item)
    end
    true
  end

  ##
  # Turns the group off. Each item keeps its current description and
  # substitutions as its own — we intentionally don't roll back so users
  # don't lose their work mid-flow.
  def disable_sync!(item)
    return false unless syncable?(item)

    ActiveRecord::Base.transaction do
      item.update_column(:notes_synced, false) if item.notes_synced?
      siblings(item).update_all(notes_synced: false, updated_at: Time.current)
    end
    true
  end

  ##
  # Called after a new grid item is created. If any existing sibling is in a
  # sync group, the new item auto-joins: it picks up the flag, description,
  # and substitution set so the user doesn't have to re-toggle.
  def adopt_for_new_item!(item)
    return false unless syncable?(item)

    leader = siblings(item).where(notes_synced: true).first
    return false unless leader

    ActiveRecord::Base.transaction do
      item.update!(notes_synced: true, description: leader.description)

      grid_type = item.class.name
      leader.substitutions.each do |sub|
        next if sub.substitute_grid_id == item.id && sub.substitute_grid_type == grid_type

        item.substitutions.create!(
          substitute_grid_id: sub.substitute_grid_id,
          substitute_grid_type: sub.substitute_grid_type,
          position: sub.position
        )
      end
    end
    true
  end
end
