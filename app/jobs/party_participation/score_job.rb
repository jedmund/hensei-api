# frozen_string_literal: true

module PartyParticipation
  # Recomputes one party's participation score, e.g. after a sticker changes.
  class ScoreJob < ApplicationJob
    queue_as :maintenance

    def perform(party_id)
      Persister.call([party_id])
    end
  end
end
