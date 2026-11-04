# frozen_string_literal: true

##
# A batch of moves, swaps and removals on a party's grid, applied together.
#
# Every operation's shape is checked before any is applied (#errors); then
# #apply! runs them in order in one transaction, so a failing operation
# rolls the whole batch back. Moves and swaps follow GridPlacement's slot
# rules, the same as the single-row position and swap endpoints.
#
# Each operation is a hash (or permitted parameters) with:
# - type: 'move' (id, position), 'swap' (source_id, target_id) or 'remove' (id)
# - entity: 'weapon', 'character' or 'summon'
class PartyGridOperations
  MODELS = { 'weapon' => GridWeapon, 'character' => GridCharacter, 'summon' => GridSummon }.freeze

  # The fields each operation type needs.
  REQUIRED_FIELDS = { 'move' => %i[id position], 'swap' => %i[source_id target_id], 'remove' => %i[id] }.freeze

  ##
  # @param party [Party] the party whose rows the operations name
  # @param operations [Array<Hash, ActionController::Parameters>]
  # @param maintain_character_sequence [Boolean] close gaps in the main
  #   character slots after the batch
  # @raise [ArgumentError] when there is no operations list
  def initialize(party, operations, maintain_character_sequence: false)
    raise ArgumentError, 'operations are required' if operations.nil?

    @party = party
    @operations = operations
    @maintain_character_sequence = maintain_character_sequence
  end

  ##
  # What is wrong with the operations' shapes, one message per problem.
  #
  # @return [Array<String>] empty when the batch can be applied
  def errors
    @operations.each_with_index.flat_map do |operation, index|
      shape_errors(operation).map { |error| "Operation #{index}: #{error}" }
    end
  end

  ##
  # Applies the operations in order, in one transaction. A swap or removal
  # whose rows aren't in the party is skipped.
  #
  # @return [Array<Hash>] one change per applied operation
  # @raise [ActiveRecord::RecordNotFound] when a move names a row not in the party
  # @raise [GridPlacement::Error] when a move or swap breaks the slot rules
  # @raise [ActiveRecord::RecordInvalid] when a row fails to save
  def apply!
    ActiveRecord::Base.transaction do
      changes = @operations.filter_map { |operation| apply_operation(operation) }
      GridPlacement.compact_main_character_slots!(@party) if @maintain_character_sequence
      changes
    end
  end

  private

  def shape_errors(operation)
    type = operation[:type]
    errors = if REQUIRED_FIELDS.key?(type)
               REQUIRED_FIELDS[type].reject { |field| operation[field].present? }.map { |field| "missing #{field}" }
             else
               ["unknown operation type #{type}"]
             end
    errors << "invalid entity type #{operation[:entity]}" unless MODELS.key?(operation[:entity])
    errors
  end

  def apply_operation(operation)
    case operation[:type]
    when 'move' then move(operation)
    when 'swap' then swap(operation)
    when 'remove' then remove(operation)
    end
  end

  def move(operation)
    item = find_row(operation, operation[:id])
    raise ActiveRecord::RecordNotFound, "#{operation[:entity]} #{operation[:id]} not found" unless item

    from = item.position
    raise ActiveRecord::RecordInvalid, item unless GridPlacement.move(item, operation[:position].to_i).saved

    { entity: operation[:entity], id: operation[:id], action: 'moved', from: from, to: operation[:position] }
  end

  def swap(operation)
    source = find_row(operation, operation[:source_id])
    target = find_row(operation, operation[:target_id])
    return unless source && target

    GridPlacement.swap!(source, target)
    { entity: operation[:entity], id: operation[:source_id], action: 'swapped', with: operation[:target_id] }
  end

  def remove(operation)
    item = find_row(operation, operation[:id])
    return unless item

    item.destroy
    { entity: operation[:entity], id: operation[:id], action: 'removed' }
  end

  # Only rows of this party: an id from another party finds nothing.
  def find_row(operation, id)
    MODELS.fetch(operation[:entity]).find_by(id: id, party_id: @party.id)
  end
end
