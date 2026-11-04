# frozen_string_literal: true

##
# Who may view a party: its visibility (1 public, 2 unlisted, 3 private),
# its owner, admins in admin mode, and the crews it is shared with.
#
# `.viewable_by` (SQL) and `#viewable_by?` (Ruby) are the same permission
# check and must stay in agreement.
module Party::Visibility
  extend ActiveSupport::Concern

  included do
    ##
    # Parties the given user may view. The SQL counterpart of #viewable_by?;
    # the two must stay in agreement. Composes onto association scopes such as
    # `party.remixes` or `playlist.parties`.
    #
    # @param user [User, nil] the viewer.
    # @param admin_mode [Boolean] whether an admin viewer is in admin mode.
    scope :viewable_by, lambda { |user, admin_mode: false|
      visible = where(visibility: [1, 2])

      if user.nil?
        visible
      elsif user.admin? && admin_mode
        all
      else
        visible = visible.or(where(user_id: user.id))
        crew = user.crew
        if crew
          shared_ids = PartyShare.where(shareable_type: 'Crew', shareable_id: crew.id).select(:party_id)
          visible = visible.or(where(id: shared_ids))
        end
        visible
      end
    }
  end

  ##
  # Determines if the party is public.
  #
  # @return [Boolean] true if the party is public; false otherwise.
  def public?
    visibility == 1
  end

  ##
  # Determines if the party is unlisted.
  #
  # @return [Boolean] true if the party is unlisted; false otherwise.
  def unlisted?
    visibility == 2
  end

  ##
  # Determines if the party is private.
  #
  # @return [Boolean] true if the party is private; false otherwise.
  def private?
    visibility == 3
  end

  ##
  # Checks if the party is shared with a specific crew.
  #
  # @param crew [Crew] the crew to check.
  # @return [Boolean] true if shared with the crew; false otherwise.
  def shared_with_crew?(crew)
    return false unless crew

    party_shares.exists?(shareable_type: 'Crew', shareable_id: crew.id)
  end

  ##
  # Checks if a user can view this party based on visibility and sharing rules.
  # A user can view if:
  # - The party is public
  # - The party is unlisted (accessible via direct link)
  # - They own the party
  # - They are an admin
  # - The party is shared with a crew they belong to
  #
  # @param user [User, nil] the user to check.
  # @return [Boolean] true if the user can view the party; false otherwise.
  def viewable_by?(user, admin_mode: false)
    return true if public?
    return true if unlisted?
    return true if user && user_id == user.id
    return true if user&.admin? && admin_mode
    return true if user&.crew && shared_with_crew?(user.crew)

    false
  end

  ##
  # Whether a provided edit key is this party's. Both keys are compared with
  # surrounding whitespace trimmed, in constant time; a blank key never matches.
  #
  # @param provided [String, nil] the key the client sent.
  # @return [Boolean]
  def edit_key_matches?(provided)
    provided = provided.to_s.strip.force_encoding('UTF-8')
    stored = edit_key.to_s.strip.force_encoding('UTF-8')

    provided.present? && provided.bytesize == stored.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(provided, stored)
  end
end
