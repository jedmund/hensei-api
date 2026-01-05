# frozen_string_literal: true

module PartyShareErrors
  # Base class for all party share-related errors
  class PartyShareError < StandardError
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

  class NotInCrewError < PartyShareError
    def http_status
      :unprocessable_entity
    end

    def code
      'not_in_crew'
    end

    def message
      'You must be in a crew to share parties'
    end
  end

  class NotPartyOwnerError < PartyShareError
    def http_status
      :forbidden
    end

    def code
      'not_party_owner'
    end

    def message
      'Only the party owner can share this party'
    end
  end

  class AlreadySharedError < PartyShareError
    def http_status
      :conflict
    end

    def code
      'already_shared'
    end

    def message
      'This party is already shared with this crew'
    end
  end

  class CanOnlyShareToOwnCrewError < PartyShareError
    def http_status
      :forbidden
    end

    def code
      'can_only_share_to_own_crew'
    end

    def message
      'You can only share parties with your own crew'
    end
  end
end
