# frozen_string_literal: true

##
# The Evoking Solomonis side of a party (1:1): route Evoker, pledge level and,
# once a game report is imported, how the expedition went (outcome, end time,
# stats, the report's ID).
#
# The route Evoker decides the party's zone (raid) and element. Change it
# through the party (`party.assign_solomonis_route(character)` or nested
# `solomonis_expedition_attributes`), which keeps raid and element in step;
# saving a route change on the expedition alone fails validation when the
# party's raid or element no longer match.
#
# user_id is copied from the party so a game report can be imported once per user.
class SolomonisExpedition < ApplicationRecord
  # Where the expedition ended, by bosses defeated (0, 1, 2). Null means not set.
  OUTCOMES = %w[miasma_1 miasma_2 cleared].freeze
  MAX_BOSSES = OUTCOMES.size - 1
  PLEDGE_LEVELS = (0..5)
  STATS_KEYS = %w[battle strong terrifying ruler boss event healing chest teleporter special
                  shop_purchases points_earned].freeze
  # Fields that describe one expedition, cleared on remix (with stats).
  EXPEDITION_RESULT_FIELDS = %i[outcome game_report_id ended_at].freeze

  belongs_to :party, inverse_of: :solomonis_expedition
  belongs_to :user, optional: true
  belongs_to :route_evoker, class_name: 'Character'

  amoeba do
    EXPEDITION_RESULT_FIELDS.each { |field| nullify field }
    customize(->(_original, copy) { copy.stats = {} })
  end

  before_validation :copy_user_from_party
  before_validation :normalize_stats

  validates :party_id, uniqueness: true, allow_nil: true
  validates :pledge_level, numericality: { only_integer: true }, inclusion: { in: PLEDGE_LEVELS }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true
  validates :game_report_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :game_report_id, uniqueness: { scope: :user_id }, allow_nil: true, if: :user_id?

  validate :route_evoker_eligible
  validate :route_matches_party
  validate :stats_shape

  # @param bosses [Integer] bosses defeated, 0..MAX_BOSSES
  # @return [String, nil] the outcome for that many bosses
  def self.outcome_for_bosses(bosses)
    bosses.is_a?(Integer) && bosses >= 0 ? OUTCOMES[bosses] : nil
  end

  def zone
    route_evoker&.solomonis_zone
  end

  private

  def copy_user_from_party
    self.user_id = party&.user_id
  end

  def normalize_stats
    self.stats = {} if stats.nil?
  end

  def route_evoker_eligible
    return unless route_evoker
    return if route_evoker.solomonis_route_eligible?

    errors.add(:route_evoker, 'must be an Evoker that can lead an Evoking Solomonis expedition')
  end

  def route_matches_party
    return unless party && route_evoker&.solomonis_route_eligible?

    errors.add(:route_evoker, "must belong to the party's zone") if party.raid_id != route_evoker.solomonis_zone_id
    return if route_evoker.element.nil? || party.element == route_evoker.element

    errors.add(:route_evoker, "must match the party's element")
  end

  def stats_shape
    unless stats.is_a?(Hash)
      errors.add(:stats, 'must be an object')
      return
    end

    unknown = stats.keys.map(&:to_s) - STATS_KEYS
    errors.add(:stats, "has unknown keys: #{unknown.join(', ')}") if unknown.any?
    return if stats.values.all? { |v| v.is_a?(Integer) && !v.negative? }

    errors.add(:stats, 'values must be non-negative integers')
  end
end
