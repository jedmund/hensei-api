# frozen_string_literal: true

##
# Reorders every substitution in one slot of a party in a single
# transaction. The batch must cover all of the slot's substitutions;
# partial batches are rejected so rows that weren't sent never need
# reconciling.
#
# @example
#   SubstitutionReorder.new(party, [{ 'id' => id, 'position' => 0 }, ...]).call
#   # => the slot's substitutions, ordered by their new position
class SubstitutionReorder
  # The batch can't be applied. The message is shown to the user.
  class Invalid < StandardError; end
  # An entry belongs to another party. Reported as not found so ids in
  # other parties aren't revealed.
  class NotFound < StandardError; end

  # Park value added to every row's position during the two-pass reorder.
  # Has to be above the validated max (10) so the temporary slot never
  # collides with a valid final position; 100 leaves plenty of headroom.
  PARK_OFFSET = 100
  MAX_POSITION = 10

  # @param party [Party] the authorized party the slot must belong to
  # @param raw_entries [Array<ActionController::Parameters, Hash>, nil] { id:, position: } rows
  def initialize(party, raw_entries)
    @party = party
    @raw_entries = raw_entries
  end

  # @return [ActiveRecord::Relation<Substitution>]
  # @raise [Invalid, NotFound]
  # @raise [ActiveRecord::RecordNotUnique] when positions collide
  def call
    # A missing, empty or non-array value is refused the same way
    raise Invalid, 'substitutions array required' unless @raw_entries.is_a?(Array) && @raw_entries.present?

    entries = normalize(@raw_entries)
    ids = entries.map(&:first)
    check_batch!(ids, entries.map(&:last))
    grid_type, grid_id = slot_for!(ids)

    ApplicationRecord.transaction { apply!(entries, grid_type, grid_id) }

    Substitution.where(grid_type: grid_type, grid_id: grid_id).order(:position)
  end

  private

  # [[id, position], ...]
  def normalize(raw_entries)
    raw_entries.map do |e|
      entry = e.is_a?(ActionController::Parameters) ? e.permit(:id, :position).to_h : e.to_h
      [entry['id'] || entry[:id], (entry['position'] || entry[:position]).to_i]
    end
  end

  def check_batch!(ids, positions)
    raise Invalid, 'duplicate ids in batch' if ids.length != ids.uniq.length
    raise Invalid, 'duplicate positions in batch' if positions.length != positions.uniq.length
    raise Invalid, 'position must be in [0, 10)' if positions.any? { |p| p.negative? || p >= MAX_POSITION }
  end

  # The one slot every entry belongs to, when the batch covers all of it
  def slot_for!(ids)
    substitutions = Substitution.where(id: ids).to_a
    raise Invalid, 'unknown substitution id(s)' if substitutions.length != ids.length
    raise NotFound if substitutions.any? { |s| s.grid&.party_id != @party.id }

    slot_keys = substitutions.map { |s| [s.grid_type, s.grid_id] }.uniq
    raise Invalid, 'all entries must belong to the same slot' if slot_keys.length > 1

    grid_type, grid_id = slot_keys.first
    existing_ids = Substitution.where(grid_type: grid_type, grid_id: grid_id).pluck(:id)
    raise Invalid, 'reorder batch must cover all substitutions in the slot' if existing_ids.sort != ids.sort

    [grid_type, grid_id]
  end

  def apply!(entries, grid_type, grid_id)
    ids = entries.map(&:first)
    # Two-pass write to dodge the unique index on
    # (grid_type, grid_id, position): park every row at position+100
    # (well above the validated max), then restamp the final positions.
    # update_all bypasses validation so the temporary value is allowed;
    # the second pass uses update! so the [0,9] validator still fires.
    Substitution.where(id: ids).update_all("position = position + #{PARK_OFFSET}")

    by_id = Substitution.where(id: ids).index_by(&:id)
    entries.each { |id, position| by_id[id].update!(position: position) }
    @party.mark_updated!
    # Reorder runs on a single primary slot — fan out the new order to
    # any siblings sharing the notes sync group.
    primary = grid_type.constantize.find_by(id: grid_id)
    NotesSync.propagate_substitutions!(primary) if primary
  end
end
