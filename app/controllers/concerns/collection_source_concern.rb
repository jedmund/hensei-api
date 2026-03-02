# frozen_string_literal: true

##
# Concern for validating and managing the collection source user on parties.
#
# When grid items are linked to collection items, all links must come from
# the same user's collection. This concern enforces that constraint.
module CollectionSourceConcern
  extend ActiveSupport::Concern

  private

  ##
  # Validates that a collection item is accessible and consistent with the party's
  # existing collection source. Sets the collection source if not yet set.
  #
  # @param party [Party] the party being modified
  # @param collection_item [CollectionCharacter, CollectionWeapon, CollectionSummon, nil]
  # @return [Boolean] true if valid, false if a response was rendered (caller should return)
  def validate_collection_source!(party, collection_item)
    return true unless collection_item

    owner = collection_item.user

    # The collection must be accessible: either owned by the current user,
    # or the owner's collection is viewable by the current user (handles crew_only/everyone)
    unless owner == current_user || owner.collection_viewable_by?(current_user)
      render_forbidden_response('Collection is not accessible')
      return false
    end

    # All collection items in a party must come from the same user
    if party.collection_source_user_id.present? && party.collection_source_user_id != owner.id
      render_unprocessable_entity_response(
        Api::V1::GranblueError.new('Cannot mix collection items from different users. Clear the existing collection source first.')
      )
      return false
    end

    # Set the source user if this is the first collection-linked item
    if party.collection_source_user_id.nil?
      party.update_column(:collection_source_user_id, owner.id)
    end

    true
  end

  ##
  # Clears the party's collection_source_user_id if no collection-linked
  # grid items remain across characters, weapons, and summons.
  #
  # @param party [Party] the party to check
  # @return [void]
  def clear_collection_source_if_empty!(party)
    return unless party.collection_source_user_id.present?

    has_links = party.characters.where.not(collection_character_id: nil).exists? ||
                party.weapons.where.not(collection_weapon_id: nil).exists? ||
                party.summons.where.not(collection_summon_id: nil).exists?

    party.update_column(:collection_source_user_id, nil) unless has_links
  end
end
