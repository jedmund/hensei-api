# frozen_string_literal: true

module AccountDeletion
  # Permanently deletes an account whose deletion date has passed. Most of the
  # user's data goes with it through the User associations; records shared with
  # a crew or other users stay, unattributed (see the nullify associations on
  # User).
  class Purge
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    # Returns false without deleting anything if the deletion was cancelled
    # since the job picked the user up.
    def call
      purged = false

      User.transaction do
        @user.lock!
        if due?
          hand_off_captaincy
          release_phantom_claims
          revoke_sessions
          @user.destroy!
          purged = true
        end
      end

      purged
    end

    private

    def due?
      @user.deletion_scheduled_at.present? && @user.deletion_scheduled_at <= Time.current
    end

    # A crew keeps going without its captain: the longest-serving vice captain
    # takes over, then the longest-serving member. A crew with nobody left is
    # deleted.
    def hand_off_captaincy
      membership = @user.active_crew_membership
      return unless membership&.captain?

      crew = membership.crew
      membership.destroy!

      successor = crew.active_memberships.where(role: :vice_captain).order(:joined_at, :created_at).first ||
                  crew.active_memberships.order(:joined_at, :created_at).first

      if successor
        successor.update!(role: :captain)
      else
        crew.destroy!
      end
    end

    # A phantom the user claimed goes back to being unclaimed, so the crew's
    # score history stays intact.
    def release_phantom_claims
      @user.claimed_phantom_players.update_all(claimed_by_id: nil, claim_confirmed: false)
    end

    # Doorkeeper rows reference the user by id without a foreign key.
    def revoke_sessions
      Doorkeeper::AccessToken.where(resource_owner_id: @user.id).delete_all
      Doorkeeper::AccessGrant.where(resource_owner_id: @user.id).delete_all
    end
  end
end
