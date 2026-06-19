# frozen_string_literal: true

module PartyDifficulty
  class ScoreJob < ApplicationJob
    queue_as :maintenance

    discard_on ActiveRecord::RecordNotFound

    def perform(party_id)
      Persister.call(party_id)
    end
  end
end
