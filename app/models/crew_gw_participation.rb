# frozen_string_literal: true

class CrewGwParticipation < ApplicationRecord
  belongs_to :crew
  belongs_to :gw_event

  has_many :gw_crew_scores, dependent: :destroy
  has_many :gw_individual_scores, dependent: :destroy

  validates :crew_id, uniqueness: { scope: :gw_event_id, message: 'is already participating in this event' }

  # Get total crew score across all rounds (from crew battles)
  def total_crew_score
    gw_crew_scores.sum(:crew_score)
  end

  # Get total individual honors (sum of all member scores)
  def total_individual_honors
    if gw_individual_scores.loaded?
      gw_individual_scores.sum(&:score)
    else
      gw_individual_scores.sum(:score)
    end
  end

  # Get wins count
  def wins_count
    gw_crew_scores.where(victory: true).count
  end

  # Get losses count
  def losses_count
    gw_crew_scores.where(victory: false).count
  end

  # Get individual scores for a specific round
  def individual_scores_for_round(round)
    gw_individual_scores.where(round: round).includes(:crew_membership)
  end

  # Get leaderboard - members ranked by total score
  def leaderboard
    gw_individual_scores
      .select('crew_membership_id, SUM(score) as total_score')
      .group(:crew_membership_id)
      .order('total_score DESC')
  end
end
