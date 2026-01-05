# frozen_string_literal: true

##
# PartyShare represents a sharing relationship between a party and a group (e.g., a crew).
# It allows party owners to share their parties with specific groups, granting view access
# to members of those groups without changing the party's base visibility.
#
# @!attribute [rw] party
#   @return [Party] the party being shared.
# @!attribute [rw] shareable
#   @return [Crew] the polymorphic group the party is shared with.
# @!attribute [rw] shared_by
#   @return [User] the user who created this share.
class PartyShare < ApplicationRecord
  # Associations
  belongs_to :party
  belongs_to :shareable, polymorphic: true
  belongs_to :shared_by, class_name: 'User'

  # Validations
  validates :party_id, uniqueness: {
    scope: [:shareable_type, :shareable_id],
    message: 'has already been shared with this group'
  }
  validate :owner_can_share
  validate :sharer_is_member_of_shareable

  # Scopes
  scope :for_crew, ->(crew) { where(shareable_type: 'Crew', shareable_id: crew.id) }
  scope :for_crews, ->(crew_ids) { where(shareable_type: 'Crew', shareable_id: crew_ids) }
  scope :for_party, ->(party) { where(party_id: party.id) }

  ##
  # Returns the blueprint class for serialization.
  #
  # @return [Class] the PartyShareBlueprint class.
  def blueprint
    PartyShareBlueprint
  end

  private

  ##
  # Validates that only the party owner can share the party.
  #
  # @return [void]
  def owner_can_share
    return if party&.user_id == shared_by_id

    errors.add(:shared_by, 'must be the party owner')
  end

  ##
  # Validates that the sharer is a member of the group they're sharing to.
  #
  # @return [void]
  def sharer_is_member_of_shareable
    return unless shareable_type == 'Crew'
    return if shareable&.active_memberships&.exists?(user_id: shared_by_id)

    errors.add(:shareable, 'you must be a member of this crew')
  end
end
