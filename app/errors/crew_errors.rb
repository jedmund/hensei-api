# frozen_string_literal: true

module CrewErrors
  # Base class for all crew-related errors
  class CrewError < StandardError
    def http_status
      :unprocessable_entity
    end

    def code
      self.class.name.demodulize.underscore
    end

    def to_hash
      {
        message: message,
        code: code
      }
    end
  end

  class AlreadyInCrewError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'already_in_crew'
    end

    def message
      'You are already in a crew'
    end
  end

  class CaptainCannotLeaveError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'captain_cannot_leave'
    end

    def message
      'Captain must transfer ownership before leaving'
    end
  end

  class CannotRemoveCaptainError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'cannot_remove_captain'
    end

    def message
      'Cannot remove the captain from the crew'
    end
  end

  class ViceCaptainLimitError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'vice_captain_limit'
    end

    def message
      'Crew can only have up to 3 vice captains'
    end
  end

  class NotInCrewError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'not_in_crew'
    end

    def message
      'You are not in a crew'
    end
  end

  class MemberNotFoundError < CrewError
    def http_status
      :not_found
    end

    def code
      'member_not_found'
    end

    def message
      'Member not found in this crew'
    end
  end

  class CannotDemoteCaptainError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'cannot_demote_captain'
    end

    def message
      'Cannot demote the captain'
    end
  end

  class InvitationExpiredError < CrewError
    def http_status
      :gone
    end

    def code
      'invitation_expired'
    end

    def message
      'This invitation has expired'
    end
  end

  class InvitationNotFoundError < CrewError
    def http_status
      :not_found
    end

    def code
      'invitation_not_found'
    end

    def message
      'Invitation not found'
    end
  end

  class CannotInviteSelfError < CrewError
    def http_status
      :unprocessable_entity
    end

    def code
      'cannot_invite_self'
    end

    def message
      'You cannot invite yourself'
    end
  end

  class UserAlreadyInvitedError < CrewError
    def http_status
      :conflict
    end

    def code
      'user_already_invited'
    end

    def message
      'User already has a pending invitation'
    end
  end

  class NotClaimedByUserError < CrewError
    def http_status
      :forbidden
    end

    def code
      'not_claimed_by_user'
    end

    def message
      'This phantom player is not assigned to you'
    end
  end

  class PhantomNotFoundError < CrewError
    def http_status
      :not_found
    end

    def code
      'phantom_not_found'
    end

    def message
      'Phantom player not found'
    end
  end
end
