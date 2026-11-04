# frozen_string_literal: true

##
# Where grid rows (weapons, characters, summons) may sit in a party, and
# what placing one does:
# - a weapon in the mainhand sets the party's element, and one in an extra
#   slot (9-11) marks the party as using extra slots;
# - a character moving between the main (0-4) and extra (5-7) slots closes
#   the gap in the main slots;
# - the main and friend summon slots can't be moved into or swapped.
module GridPlacement
  # A row can't go where it was asked to. The message is shown to the user.
  class Error < StandardError; end
  class InvalidPosition < Error; end
  class PositionOccupied < Error; end

  # positions: the slots a row may move to; restricted_positions: slots rows
  # can't be moved into or swapped out of.
  Rules = Data.define(:positions, :restricted_positions)

  RULES = {
    'GridWeapon' => Rules.new(positions: [-1, *0..11].freeze, restricted_positions: [].freeze),
    'GridCharacter' => Rules.new(positions: (0..7), restricted_positions: [].freeze),
    'GridSummon' => Rules.new(positions: [-1, *0..6].freeze, restricted_positions: [-1, 6].freeze)
  }.freeze

  CHARACTER_MAIN_SLOTS = (0..4)
  CHARACTER_EXTRA_SLOTS = (5..7)

  # Where a row waits while two rows trade slots, so positions never clash.
  SWAP_PARKING_POSITION = -999

  # saved: whether the row saved; reordered: whether the main character slots
  # were compacted after the move.
  Move = Data.define(:saved, :reordered)

  module_function

  ##
  # Moves a row to an empty slot in its party and saves it.
  #
  # @param grid_item [GridWeapon, GridCharacter, GridSummon]
  # @param position [Integer]
  # @return [Move]
  # @raise [InvalidPosition, PositionOccupied] when the row can't go there
  def move(grid_item, position)
    check_move!(grid_item, position)

    old_position = grid_item.position
    grid_item.position = position
    claim_slot!(grid_item, position) if grid_item.is_a?(GridWeapon)
    return Move.new(saved: false, reordered: false) unless grid_item.save

    reordered = grid_item.is_a?(GridCharacter) && crosses_character_slots?(old_position, position)
    compact_main_character_slots!(grid_item.party) if reordered
    Move.new(saved: true, reordered: reordered)
  end

  ##
  # Trades the slots of two rows of the same party.
  #
  # @param source [GridWeapon, GridCharacter, GridSummon]
  # @param target [GridWeapon, GridCharacter, GridSummon] a row of the same kind
  # @return [void]
  # @raise [InvalidPosition] when either row sits in a restricted slot
  # @raise [ActiveRecord::RecordInvalid] when either row fails to save
  def swap!(source, target)
    restricted = rules_for(source).restricted_positions
    if restricted.include?(source.position) || restricted.include?(target.position)
      raise InvalidPosition, "Cannot swap #{kind(source)}s in restricted positions"
    end

    ActiveRecord::Base.transaction do
      source_position = source.position
      target_position = target.position

      source.update!(position: SWAP_PARKING_POSITION)
      target.update!(position: source_position)
      source.update!(position: target_position)
    end
  end

  ##
  # Updates the party for a weapon taking a slot: the mainhand sets the
  # party's element, and an extra slot marks the party as using extra slots.
  #
  # @param grid_weapon [GridWeapon]
  # @param position [Integer] the slot it takes
  # @param party [Party] the party to update
  # @return [void]
  def claim_slot!(grid_weapon, position, party: grid_weapon.party)
    if position == -1
      party.element = grid_weapon.weapon.element
      party.save!
    elsif GridWeapon::EXTRA_POSITIONS.include?(position)
      party.extra = true
      party.save!
    end
  end

  def check_move!(grid_item, position)
    rules = rules_for(grid_item)
    if rules.positions.exclude?(position)
      raise InvalidPosition, "Invalid position #{position} for #{kind(grid_item)}"
    elsif rules.restricted_positions.include?(position)
      raise InvalidPosition, "Cannot move #{kind(grid_item)} to restricted position #{position}"
    elsif grid_item.class.exists?(party_id: grid_item.party_id, position: position)
      raise PositionOccupied, "Position #{position} is already occupied"
    end
  end

  # Closes the gap in the main character slots, keeping their order.
  def compact_main_character_slots!(party)
    ActiveRecord::Base.transaction do
      party.characters.where(position: CHARACTER_MAIN_SLOTS).order(:position).each_with_index do |character, index|
        character.update!(position: index) if character.position != index
      end
    end
  end

  def crosses_character_slots?(old_position, new_position)
    main_to_extra = CHARACTER_MAIN_SLOTS.cover?(old_position) && CHARACTER_EXTRA_SLOTS.cover?(new_position)
    extra_to_main = CHARACTER_EXTRA_SLOTS.cover?(old_position) && CHARACTER_MAIN_SLOTS.cover?(new_position)
    main_to_extra || extra_to_main
  end

  def rules_for(grid_item)
    RULES.fetch(grid_item.class.name)
  end

  # 'weapon', 'character' or 'summon', for messages.
  def kind(grid_item)
    grid_item.class.name.delete_prefix('Grid').downcase
  end
end
