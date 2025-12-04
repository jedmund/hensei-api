# frozen_string_literal: true

class GwCrewScore < ApplicationRecord
  belongs_to :crew_gw_participation

  # Rounds: 0=prelims, 1=interlude, 2-5=finals day 1-4
  ROUNDS = {
    preliminaries: 0,
    interlude: 1,
    finals_day_1: 2,
    finals_day_2: 3,
    finals_day_3: 4,
    finals_day_4: 5
  }.freeze

  enum :round, ROUNDS

  validates :round, presence: true
  validates :crew_score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :opponent_score, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :round, uniqueness: { scope: :crew_gw_participation_id }

  before_save :determine_victory

  delegate :crew, :gw_event, to: :crew_gw_participation

  private

  def determine_victory
    return if opponent_score.nil?

    self.victory = crew_score > opponent_score
  end
end
