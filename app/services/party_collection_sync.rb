# frozen_string_literal: true

##
# Bulk work on the links from a party's grid items to collection items:
# pulling every linked row's data from its collection item, or dropping
# every link.
class PartyCollectionSync
  KINDS = %i[characters weapons summons artifacts].freeze

  # Counts per kind of grid item.
  Result = Data.define(:synced, :skipped)

  def initialize(party)
    @party = party
  end

  ##
  # Syncs each linked row from its collection item, in one transaction. Rows
  # whose collection item the block refuses are left as they are and counted
  # as skipped, rather than failing the whole party.
  #
  # @yieldparam collection_item [CollectionCharacter, CollectionWeapon,
  #   CollectionSummon, CollectionArtifact]
  # @yieldreturn [Boolean] whether the row may be synced from it
  # @return [Result]
  def sync_all!
    synced = KINDS.index_with(0)
    skipped = KINDS.index_with(0)

    ActiveRecord::Base.transaction do
      linked_rows.each do |kind, (rows, link)|
        rows.each do |row|
          if yield(row.public_send(link))
            row.sync_from_collection!
            synced[kind] += 1
          else
            skipped[kind] += 1
          end
        end
      end
    end

    Result.new(synced: synced, skipped: skipped)
  end

  ##
  # Drops every collection link on the party's characters, weapons and
  # summons, and its collection source. The grid items stay as they are.
  #
  # @return [void]
  def unlink!
    ActiveRecord::Base.transaction do
      # Only the link columns change: the rows skip validation and their save
      # callbacks (mainhand and awakening defaults, the summon boost recompute).
      # rubocop:disable Rails/SkipsModelValidations -- clearing link columns only; the rows must not be revalidated or re-saved
      @party.characters.where.not(collection_character_id: nil).update_all(collection_character_id: nil)
      @party.weapons.where.not(collection_weapon_id: nil).update_all(collection_weapon_id: nil, orphaned: false)
      @party.summons.where.not(collection_summon_id: nil).update_all(collection_summon_id: nil, orphaned: false)
      # rubocop:enable Rails/SkipsModelValidations
      @party.update!(collection_source_user_id: nil)
    end
  end

  private

  # Kind => [linked rows with their collection items' owners, link association].
  def linked_rows
    {
      characters: [@party.characters.where.not(collection_character_id: nil).includes(collection_character: :user),
                   :collection_character],
      weapons: [@party.weapons.where.not(collection_weapon_id: nil).includes(collection_weapon: :user), :collection_weapon],
      summons: [@party.summons.where.not(collection_summon_id: nil).includes(collection_summon: :user), :collection_summon],
      artifacts: [GridArtifact.joins(:grid_character).where(grid_characters: { party_id: @party.id })
                              .where.not(collection_artifact_id: nil).includes(collection_artifact: :user),
                  :collection_artifact]
    }
  end
end
